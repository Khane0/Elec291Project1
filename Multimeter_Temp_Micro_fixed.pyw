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
import time
import serial
import serial.tools.list_ports
import kconvert

top = Tk()
top.resizable(0,0)
top.title("Fluke_45/Tek_DMM40xx K-type Thermocouple")

#ATTENTION: Make sure the multimeter is configured at 9600 baud, 8-bits, parity none, 1 stop bit, echo Off

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

def update_temp():
    global ser, ser2, connected
    if connected == 0:
        top.after(5000, FindPort)  # Not connected, try to reconnect again in 5 seconds
        return

    # Read from multimeter (existing code)
    try:
        strin_bytes = ser.readline()  # Read the requested value, e.g. "+0.234E-3 VDC"
        strin = strin_bytes.decode(errors='ignore')
        ser.readline()  # Read and discard the prompt "=>"
        if len(strin) > 1 and strin[1] == '>':  # Out of sync?
            strin_bytes = ser.readline()
            strin = strin_bytes.decode(errors='ignore')
        ser.write(b"MEAS1?\r\n")  # Request next value from multimeter
    except Exception:
        connected = 0
        DMMout.set("----")
        Temp.set("----")
        portstatus.set("Communication Lost")
        DMM_Name.set("--------")
        top.after(5000, FindPort)
        return

    strin_clean = strin.replace("VDC", "")
    if len(strin_clean) > 0:
        DMMout.set(strin.replace("\r", "").replace("\n", ""))
        try:
            val = float(strin_clean) * 1000.0  # volts -> millivolts
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

                #fpga/adc read
                try:
                    if 'ser2' not in globals() or ser2 is None or not ser2.is_open:
                        print("FPGA serial (ser2) not open or not available.")
                    else:
                        raw = ser2.readline()  # blocking up to ser2.timeout
                        if not raw:
                            #didnt get data
                            print("No FPGA data this cycle")
                        else:
                            #try to get a float out
                            try:
                                line = raw.decode(errors='ignore').strip()
                                #*****EXPECTING A PLAIN STRING OF NUMBERS (VOLTAGE)******
                                voltOpamp = float(line)
                            except Exception:
                                print(f"Could not parse FPGA line: {raw!r}")
                                voltOpamp = None

                            if voltOpamp is not None:
                                tempFPGA = float(line)
                                #voltOpamp = float(line)
                                #tempFPGA = voltOpamp / (OPampGain * VPerC * 1000)
                                error = abs(ktemp - tempFPGA)
                                #print temps and errors to terminal
                                print(
                                    f"DMM: {ktemp:.2f} C | "
                                    f"FPGA: {tempFPGA:.2f} C | "
                                    f"Error: {error:.2f} C | "
                                   # f"VoltOpAmp: {voltOpamp} V | " 
                                    f"raw FPGA line: {raw!r}"
                                )
                except Exception as e:
                    # never crash the update loop
                    print("FPGA read error:", e)
                #===end FPGA block===

        else:
            Temp.set("----")
    else:
        Temp.set("----")
        connected = 0

    top.after(500, update_temp)

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
         time.sleep(0.2) # for the simulator
         ser.write(b'\x03') # Request prompt from possible multimeter
         instr = ser.readline() # Read the prompt "=>"
         pstring = instr.decode();
         if len(pstring) > 1:
            if pstring[1]=='>':
               ser.timeout=3  # Three seconds timeout to receive data should be enough
               portstatus.set("Connected to " + item[0])
               ser.write(b"VDC; RATE S; *IDN?\r\n") # Measure DC voltage, set scan rate to 'Slow' for max resolution, get multimeter ID
               instr=ser.readline()
               devicename=instr.decode()
               DMM_Name.set(devicename.replace("\r", "").replace("\n", ""))
               ser.readline() # Read and discard the prompt "=>"
               ser.write(b"MEAS1?\r\n") # Request first value from multimeter
               connected=1
               top.after(1000, update_temp)
               break
            else:
               ser.close()
         else:
            ser.close()
      except:
         connected=0
   if connected==0:
      portstatus.set("Multimeter not found")
      top.after(5000, FindPort) # Try again in 5 seconds

Label(top, text="Cold Junction Temperature:").grid(row=1, column=0)
Entry(top, bd =1, width=7, textvariable=CJTemp).grid(row=2, column=0)
Label(top, text="Multimeter reading:").grid(row=3, column=0)
Label(top, text="xxxx", textvariable=DMMout, width=20, font=("Helvetica", 20), fg="red").grid(row=4, column=0)
Label(top, text="Thermocouple Temperature (C)").grid(row=5, column=0)
Label(top, textvariable=Temp, width=5, font=("Helvetica", 100), fg="blue").grid(row=6, column=0)
Label(top, text="xxxx", textvariable=portstatus, width=40, font=("Helvetica", 12)).grid(row=7, column=0)
Label(top, text="xxxx", textvariable=DMM_Name, width=40, font=("Helvetica", 12)).grid(row=8, column=0)
Button(top, width=11, text = "Exit", command = Just_Exit).grid(row=9, column=0)

CJTemp.set ("22")
DMMout.set ("NO DATA")
DMM_Name.set ("--------")

port = 'COM9' # Change to the serial port assigned to your board

try:
   ser2 = serial.Serial(port, 57600, timeout=1) # changed to 57600 from 115200
except:
   print('Serial port %s is not available' % (port))
   portlist=list(serial.tools.list_ports.comports())
   print('Available serial ports:')
   for item in portlist:
      print (item[0])

top.after(500, FindPort)
top.mainloop()
