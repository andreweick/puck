# SOPS + Age quick setup
age-keygen -o age.key
export SOPS_AGE_KEY_FILE=$PWD/age.key
# Put the public recipient (age1...) into .sops.yaml

# After Flux bootstrap:
kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=./age.key

# Encrypt any secret.*.yaml file in-place:
# sops -e -i path/to/secret.whatever.yaml
