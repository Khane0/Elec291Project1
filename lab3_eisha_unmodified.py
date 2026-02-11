import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math
import serial
import re
import os
os.system("")

ser = serial.Serial(
port='COM5',
baudrate=115200,
parity=serial.PARITY_NONE,
stopbits=serial.STOPBITS_TWO,
bytesize=serial.EIGHTBITS,
)


xsize=100
yLower = 0
yUpper = 50
ansi_escape = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')

   
def data_gen():
    t = 0
    while True:
        strin = ser.readline().decode().strip()
        strin = ansi_escape.sub('', strin)
        #print(strin)
        #print(f"\033[32m{strin}\033[0m")

        try:
            temp = float(strin)

            if temp > 30:          
                color = 31         #red
            else:
                color = 32         #green

            print(f"\033[{color}m{temp:.2f}\033[0m") #stupid etra print thing

            yield t, temp
            t += 1
        except ValueError: #hit errors? i dont care
            continue

    ser.close()

def run(data):
    t,y = data

    if t > -1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)

    #extra, idk
    tempText.set_text(f"T = {y:.1f} °C")

    return line, tempText

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)

#extra, idk
tempText = ax.text(0.02, 0.95, '', transform=ax.transAxes, fontsize=12, verticalalignment='top')

ax.set_ylim(yLower, yUpper)
ax.set_xlim(0, xsize)
ax.set_ylabel("Temperature (deg. Celsius)")
ax.grid()
xdata, ydata = [], []


# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen(), blit=False, interval=100, repeat=False)
plt.show()

#while True:
    #plt.pause(0.1)

#& "C:\Users\eisha\WPy64-31241\python-3.12.4.amd64\python.exe" elec291lab3python.py 
#paste this into vscode terminal to run the script with ansi stuff
