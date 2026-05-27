import sys

input_file = sys.argv[1]
chunk_size = 4000

chunk = 1
count = 0
out_f = open(f"chunk_{chunk}.faa", "w")

with open(input_file, "r") as in_f:
    for line in in_f:
        if line.startswith(">"):
            if count >= chunk_size:
                out_f.close()
                chunk += 1
                out_f = open(f"chunk_{chunk}.faa", "w")
                count = 0
            count += 1
        out_f.write(line)

out_f.close()
print(f"Done! Split into {chunk} files.")
