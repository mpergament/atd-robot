import yaml

with open('/etc/atd/ACCESS_INFO.yaml') as file:
    # The FullLoader parameter handles the conversion from YAML
    # scalar values to Python the dictionary format
    full_topo_info = yaml.load(file, Loader=yaml.FullLoader)

    topology = full_topo_info['topology']
