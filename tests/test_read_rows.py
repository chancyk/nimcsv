import time
import nimcsv

t0 = time.monotonic()


schema = dict([
    ('Index', int),
    ('INPT ID', str),
    ('Well Name', str),
    ('Gross Oil Well Head Volume (MBBL)', float),
    ('Gross Gas Well Head Volume (MMCF)', float),
    ('Gross NGL Sales Volume (MBBL)', float),
    ('Gross Water Well Head Volume (MBBL)', float),
    ('Net Oil Sales Volume (MBBL)', float),
    ('Net Gas Sales Volume (MMCF)', float),
    ('Net NGL Sales Volume (MBBL)', float),
    ('Net Oil Revenue (M$)', float),
    ('Net Gas Revenue (M$)', float),
    ('Net NGL Revenue (M$)', float),
    ('Net Profit (M$)', float),
    ('Total Net Revenue (M$)', float),
    ('Total Severance Tax (M$)', float),
    ('Ad Valorem Tax (M$)', float),
    ('Total Abandonment (M$)', float),
    ('Total CAPEX (M$)', float),
    ('Total Fixed Expense (M$)', float),
    ('Total Variable Expense (M$)', float),
    ('Oil Severance Tax (M$)', float),
    ('Gas Severance Tax (M$)', float),
    ('NGL Severance Tax (M$)', float),
    ('Before Income Tax Cash Flow (M$)', float)
])

num_rows = 0
reader = nimcsv.Reader(filepath=r"C:\Projects\nimcsv\sample.csv", schema=schema, only_schema=False)
for row in reader.read_rows(skip_header=False):
    num_rows += 1
    if num_rows % 100_000 == 0:
        print("Row: ", num_rows)
        print(row)

t1 = time.monotonic()

elapsed = t1 - t0
print("# Rows: ", num_rows)
print(f"Elapsed: {elapsed}s")
