#!/usr/bin/env python
# -*- coding: utf-8 -*-

import time
import signal
import sys
import RPi.GPIO as GPIO

# --- PIN CONFIGURATION (HAT NXEZ) ---
LED_MOSI = 17
LED_SCLK = 4
PIN_FAN = 18

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(LED_MOSI, GPIO.OUT)
GPIO.setup(LED_SCLK, GPIO.OUT)
GPIO.setup(PIN_FAN, GPIO.OUT)

# Configure the fan in PWM mode (100 Hz)
pwm_fan = GPIO.PWM(PIN_FAN, 100)
pwm_fan.start(0)

# --- LED DRIVER FUNCTIONS (Bit-banging) ---
def write_byte(val):
    for bit in range(7, -1, -1):
        GPIO.output(LED_MOSI, (val >> bit) & 1)
        GPIO.output(LED_SCLK, GPIO.HIGH)
        GPIO.output(LED_SCLK, GPIO.LOW)

def send_multiple_colors(colors_list):
    # Start-of-frame (32 zero bits)
    for _ in range(4):
        write_byte(0x00)
    
    # Send colors for the 4 LEDs (global brightness set to 3)
    for (r, g, b) in colors_list:
        write_byte(0xE0 | 3)  
        write_byte(b)          # Blue
        write_byte(g)          # Green
        write_byte(r)          # Red
        
    # End-of-frame
    for _ in range(4):
        write_byte(0xFF)

# --- CLEAN EXIT FUNCTION ---
def graceful_exit(signum, frame):
    print("\nService stop requested: turning off LEDs and cleaning up GPIO...")
    # Explicitly turn off the 4 LEDs
    send_multiple_colors([(0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0)])
    try:
        pwm_fan.stop()
    except:
        pass
    GPIO.cleanup()
    sys.exit(0)

# Intercept stop signals (systemd stop -> SIGTERM, Ctrl+C -> SIGINT)
signal.signal(signal.SIGTERM, graceful_exit)
signal.signal(signal.SIGINT, graceful_exit)

# --- TEMPERATURE AND GRADIENT FUNCTIONS ---
def get_cpu_temp():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as temp_file:
            cpu_temp = temp_file.read()
        return float(cpu_temp) / 1000
    except:
        return 40.0

def interpolate_color(c1, c2, factor):
    return (
        int(c1[0] + (c2[0] - c1[0]) * factor),
        int(c1[1] + (c2[1] - c1[1]) * factor),
        int(c1[2] + (c2[2] - c1[2]) * factor)
    )

def get_temperature_gradient(temp):
    t_min = 40.0
    t_max = 70.0
    ratio = max(0.0, min(1.0, (temp - t_min) / (t_max - t_min)))
    
    blue = (0, 0, 255)
    green = (0, 255, 0)
    yellow = (255, 255, 0)
    red = (255, 0, 0)
    
    if ratio < 0.33:
        base_col = interpolate_color(blue, green, ratio / 0.33)
    elif ratio < 0.66:
        base_col = interpolate_color(green, yellow, (ratio - 0.33) / 0.33)
    else:
        base_col = interpolate_color(yellow, red, (ratio - 0.66) / 0.34)
        
    colors = []
    for i in range(4):
        offset = (i - 1.5) * 0.1
        r = max(0, min(255, int(base_col[0] + offset * 80)))
        g = max(0, min(255, int(base_col[1] - abs(offset) * 40)))
        b = max(0, min(255, int(base_col[2] - offset * 80)))
        colors.append((r, g, b))
        
    return colors

# --- MAIN LOOP ---
print("Starting service (fan + 4 LED gradient with signal handling)...")
while True:
    temp = get_cpu_temp()
    
    if temp < 45:
        speed = 0
    else:
        speed = min(100, int(65 + (temp - 45) * 1.75))
        
    print(f"Temp: {temp:.1f}C -> Fan Speed: {speed}%")
    pwm_fan.ChangeDutyCycle(speed)
    
    led_colors = get_temperature_gradient(temp)
    send_multiple_colors(led_colors)
    
    time.sleep(2)
