import csv
import time

f = open("./sample.csv", 'r')
csv_reader = csv.reader(f)


t0 = time.monotonic()

num_rows = 0
for row in csv_reader:
    num_rows += 1

t1 = time.monotonic()


elapsed = t1 - t0
print("# Rows: ", num_rows)
print(f"Elapsed: {elapsed}s")
