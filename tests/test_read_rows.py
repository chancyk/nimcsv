import time
from pynimcsv import read_rows

t0 = time.monotonic()

num_rows = 0
for row in read_rows("./sample.csv"):
    num_rows += 1
    if num_rows % 100_000 == 0:
        print("Row: ", num_rows)
        print(row)

t1 = time.monotonic()

elapsed = t1 - t0
print("# Rows: ", num_rows)
print(f"Elapsed: {elapsed}s")
