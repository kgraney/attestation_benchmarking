# AWS Nitro Security Module Benchmarking

## Benchmarks

 * `Request::Attestation` - attestation flow including the Rust client library.

 * `Request::Attestation ioctl` - attestation flow including only the `ioctl()`
    call.

 * `Request::GetRandom` - sourcing entropy from the enclave.

## Running benchmarks

### Locally (very fake)

Create a very fake `/dev/nsm` that doesn't do anything but allows the system
calls in the benchmark to succeed.

```
sudo ./tools/fake_nsm.sh
```

Run the benchmarks with `cargo criterion`, `cargo bench`, or
`./tools/run_benchmarks.sh`.  The bash script will generate individual JSON
output files for each benchmark.

Results are in `./target/criterion`.  These results are very fake.

### On AWS

Launch EC2 instances configured in `main.tf`.
`terraform apply`

Wait for machines to shutdown.  Copy results down locally.
`aws s3 sync s3://nsm-benchmark-results/ ./`

Destroy EC2 instances with Terraform.

SSH is available to the instances (port 22) and enclave (port 2222).  SSH keys
are configured in Terraform.

## Notes

https://www.kernel.org/doc/Documentation/admin-guide/devices.txt

`/dev/nsm` is exposed as a char device (10).

```
-bash-4.2# ls -al /dev/nsm
crw-rw-rw- 1 root root 10, 147 Apr 20 14:13 /dev/nsm
```
