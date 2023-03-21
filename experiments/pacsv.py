import time
import pyarrow.csv as pac

t0 = time.monotonic()
table = pac.read_csv(r"C:\Temp\EOM_OnelineLarge\EOM_Historical.csv")
t1 = time.monotonic()
print("Elapsed: ", t1 - t0)
