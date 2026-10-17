import fcntl, struct, os, time, sys
fd = os.open(sys.argv[1], os.O_RDWR)
FF_RUMBLE = 0x50
eff = struct.pack('HhHHHHH2xHH28x', FF_RUMBLE, -1, 0, 0, 0, 1500, 0, 0xc000, 0xc000)
assert len(eff) == 48
buf = bytearray(eff)
fcntl.ioctl(fd, 0x40304580, buf)  # EVIOCSFF
eid = struct.unpack_from('h', buf, 2)[0]
os.write(fd, struct.pack('llHHi', 0, 0, 0x15, eid, 1))  # EV_FF play
time.sleep(1.7)
print("played effect", eid)
