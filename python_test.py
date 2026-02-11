#!/usr/bin/python
import sys
if sys.version_info[0] < 3:
    import Tkinter
    from tkinter import *
    import tkMessageBox
else:
    import tkinter as Tkinter
    from tkinter import *
    from tkinter import messagebox as tkMessageBox
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import time
import serial
import serial.tools.list_ports
import kconvert

top = Tk()
top.resizable(0,0)
top.title("Fluke_45/Tek_DMM40xx K-type Thermocouple")

VPerC = 41e-6
OPampGain = 300
CJTemp = StringVar()
Temp = StringVar()
DMMout = StringVar()
portstatus = StringVar()
DMM_Name = StringVar()
connected=0
global ser, ser2

def Just_Exit():
    top.destroy()
    try:
        ser.close()
    except:
        dummy=0

xsize=100

def data_gen():
    global ser, ser2, connected

    # === [MINIMAL FIX] make this a real generator that never ends ===
    while True:

        # [MINIMAL FIX] if not connected, keep trying but DO NOT return (return would stop animation)
        if connected == 0:
            FindPort()     
            yield -1, 0    # keep animation alive
            continue

        # Read from multimeter
        try:
            strin_bytes = ser.readline()
            strin = strin_bytes.decode(errors='ignore')
            ser.readline()  # discard "=>"
            if len(strin) > 1 and strin[1] == '>':
                strin_bytes = ser.readline()
                strin = strin_bytes.decode(errors='ignore')
            ser.write(b"MEAS1?\r\n")
        except Exception:
            connected = 0
            DMMout.set("----")
            Temp.set("----")
            portstatus.set("Communication Lost")
            DMM_Name.set("--------")
            yield -1, 0     # keep generator alive
            continue

        strin_clean = strin.replace("VDC", "").strip()
        if len(strin_clean) > 0:
            DMMout.set(strin.replace("\r", "").replace("\n", ""))
            try:
                val = float(strin_clean) * 1000.0
                valid_val = True
            except Exception:
                valid_val = False

            try:
                cj = float(CJTemp.get())
            except Exception:
                cj = 0.0

            if valid_val:
                ktemp = round(kconvert.mV_to_C(val, cj), 1)
                if ktemp < -200:
                    Temp.set("UNDER")
                elif ktemp > 1372:
                    Temp.set("OVER")
                else:
                    Temp.set(ktemp)

                    # fpga/adc read
                    try:
                        if 'ser2' not in globals() or ser2 is None or not ser2.is_open:
                            
                            yield -1, 0
                        else:
                           
                            raw = ser2.readline()
                            if not raw:
                                yield -1, 0
                            else:
                                line = raw.decode(errors='ignore').strip()

                               
                                if line.isdigit():
                                    tempFPGA = int(line)
                                    error = abs(ktemp - tempFPGA)
                                    print(
                                        f"DMM: {ktemp:.2f} C | "
                                        f"FPGA: {tempFPGA:.2f} C | "
                                        f"Error: {error:.2f} C "
                                    )

                                  
                                    data_gen.t += 1
                                    yield data_gen.t, tempFPGA
                                else:
                                 
                                    yield -1, 0

                    except Exception as e:
                        print("FPGA read error:", e)
                        yield -1, 0
            else:
                Temp.set("----")
                yield -1, 0
        else:
            Temp.set("----")
            connected = 0
            yield -1, 0


def FindPort():
   global ser, connected
   try:
       ser.close()
   except:
       dummy=0

   connected=0
   DMM_Name.set ("--------")
   portlist=list(serial.tools.list_ports.comports())
   for item in reversed(portlist):
      portstatus.set("Trying port " + item[0])
      top.update()
      try:
         ser = serial.Serial(item[0], 9600, timeout=0.5)
         time.sleep(0.2)
         ser.write(b'\x03')
         instr = ser.readline()
         pstring = instr.decode(errors='ignore')
         if len(pstring) > 1:
            if pstring[1]=='>':
               ser.timeout=3
               portstatus.set("Connected to " + item[0])
               ser.write(b"VDC; RATE S; *IDN?\r\n")
               instr=ser.readline()
               devicename=instr.decode(errors='ignore')
               DMM_Name.set(devicename.replace("\r", "").replace("\n", ""))
               ser.readline()
               ser.write(b"MEAS1?\r\n")
               connected=1

               
               break
            else:
               ser.close()
         else:
            ser.close()
      except:
         connected=0
   if connected==0:
      portstatus.set("Multimeter not found")
      # keep silent; data_gen will call FindPort again


def run(data):
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize:
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)
    return line,

def on_close_figure(event):
    sys.exit(0)

data_gen.t = 0

fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(10, 250)
ax.set_xlim(0, xsize)
ax.grid()
xdata, ydata = [], []
plt.xlabel("sample no.")
plt.ylabel("temperature")

CJTemp.set ("22")
DMMout.set ("NO DATA")
DMM_Name.set ("--------")

port = 'COM9'

# open FPGA serial BEFORE plt.show() ===
try:
   ser2 = serial.Serial(port, 57600, timeout=0)  # [MINIMAL FIX] timeout=0 to avoid blocking
except:
   ser2 = None
   print('Serial port %s is not available' % (port))
   portlist=list(serial.tools.list_ports.comports())
   print('Available serial ports:')
   for item in portlist:
      print (item[0])

# try connect DMM once before plotting ===
FindPort()

ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False, cache_frame_data=False)
plt.show()

