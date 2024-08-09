import json
import sys
from typing import Dict, List
import requests
import time
import os
import boto3
from botocore.config import Config

s3 = boto3.client('s3', config=Config(region_name='us-east-1'))

s3_bucket = ""
s3_folder = ""
prover_image_tag = None

class CircuitMetadata:
    # pk_size is in bytes
    def __init__(self, config_name, circuit_name, instance_types, pk_size, prover_image_tag):
        self.circuit_name = circuit_name
        self.instance_types = instance_types
        self.config_names = [config_name]
        self.pk_size = pk_size
        self.ram_disk_size = 40
        self.prover_image_tag = prover_image_tag
        self.s3_path = f"s3://{s3_bucket}/{s3_folder}".rstrip('/')

    def to_dict(self):
        return {
            "config_names": self.config_names,
            "circuit_name": self.circuit_name,
            "dynamic_instance_types": self.instance_types,
            "pk_size_bytes": self.pk_size,
            "ram_disk_gb": self.ram_disk_size,
            "prover_image_tag": self.prover_image_tag,
            "s3_path": self.s3_path
        }

def get_pk_size(circuit_id):
    s3_key = f"{s3_folder}{circuit_id}.pk"
    object = s3.head_object(Bucket=s3_bucket, Key=s3_key)
    file_size = object['ContentLength']
    return file_size

def download_pinning(pinning_path, circuit_id):
    s3_key = f"{s3_folder}{circuit_id}.json"
    s3.download_file(s3_bucket, s3_key, pinning_path)

def download_cids(config_path, config_name):
    s3_key = f"{s3_folder}{config_name}.cids"
    print(f"Downloading cids {s3_key} from s3://{s3_bucket}")
    s3.download_file(s3_bucket, s3_key, config_path)

# pk_size is in bytes
def select_instance_types(pk_size):
    if pk_size < 20_000_000_000:
        return ["m6a.4xlarge"]
    if pk_size > 150_000_000_000:
        return ["m6a.48xlarge"]
    if pk_size > 35_000_000_000:
        return ["m6a.12xlarge"]

static_instances = {
}

# pk size in bytes
def round_pk_size_to_gb(pk_size):
    # ram disk: pk size + 20gb (over estimate for srs) + round up to 10gb
    ram_disk_size = ((pk_size + 20_000_000_000 + 9_000_000_000) // 10_000_000_000) * 10
    return ram_disk_size

def traverse_cids(config_name, cids, circuit_id_to_metadata):
    # example cid entry 
    # [
    #   "{\"node_type\":\"Leaf\",\"depth\":0,\"initial_depth\":0}",
    #   "128146c349a865541a10ebeee0387e8858adf59af4d2aaa77932607877a62153"
    # ],

    for cid_entry in cids: 
        # here we use params as circuit_name
        circuit_name = cid_entry[0]
        circuit_id = cid_entry[1]
    
        pk_size = get_pk_size(circuit_id)
        instance_types = select_instance_types(pk_size)
        metadata = CircuitMetadata(config_name, circuit_name, instance_types, pk_size, prover_image_tag)
        metadata.ram_disk_size = round_pk_size_to_gb(pk_size)
    
        circuit_id_to_metadata[circuit_id] = metadata    
    
    

def dedup_in_order(seq):
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]

def main():
    global s3_bucket
    global s3_folder
    global prover_image_tag

    if len(sys.argv) < 4:
        print("Usage: python tree_crawler.py <config file> <circuit data dir> <output file> <s3_bucket>[optional] <s3_folder>[optional] prover_image_tag[optional]")
        print("INFO: Log into AWS for s3 read access first.")
        print("INFO: All proof tree and pinning files will be auto downloaded to the circuit data dir.")
        sys.exit(1)

    config_file = sys.argv[1]
    circuit_data_dir = sys.argv[2]
    output_file = sys.argv[3]
    if len(sys.argv) >= 4:
        s3_bucket = sys.argv[4]
        s3_folder = sys.argv[5]
        prover_image_tag = sys.argv[6]

    with open(config_file) as f:
        config = json.load(f)

    circuit_id_to_metadata = {}

    config_names = list(config["config_names"])

    for config in config_names:
        cids_path = os.path.join(circuit_data_dir, f"{config}.cids")
        download_cids(cids_path, config)
        with open(cids_path) as f:
            cids = json.load(f)

        traverse_cids(config, cids, circuit_id_to_metadata)


    circuit_id_to_metadata = {k: v.to_dict() for k, v in circuit_id_to_metadata.items()}

    data = {
        "circuit_metadata": circuit_id_to_metadata,
        "static_instances": static_instances
    }
    with open(output_file, "w") as f:
        f.write(json.dumps(data, indent=2))

if __name__ == "__main__":
    main()
