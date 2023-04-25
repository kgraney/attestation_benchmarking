use rand::RngCore;
mod aws_nsm {
    pub use aws_nitro_enclaves_nsm_api::*;
}
use aws_nitro_enclaves_nsm_api::api::Request;
use criterion::{criterion_group, criterion_main, BatchSize, BenchmarkId, Criterion, Throughput};
use libc::ioctl;
use nix::errno::Errno;
use nix::request_code_readwrite;
use serde_bytes::ByteBuf;
use std::io::{IoSlice, IoSliceMut};
use std::mem;

const DEV_FILE: &str = "/dev/nsm";
const NSM_IOCTL_MAGIC: u8 = 0x0A;
const NSM_REQUEST_MAX_SIZE: usize = 0x1000;
const NSM_RESPONSE_MAX_SIZE: usize = 0x3000;

/// NSM message structure to be used with `ioctl()`.
#[repr(C)]
struct NsmMessage<'a> {
    /// User-provided data for the request
    pub request: IoSlice<'a>,
    /// Response data provided by the NSM pipeline
    pub response: IoSliceMut<'a>,
}


struct NsmMessagePkg {
    pub req: Vec<u8>,
    pub res: [u8; NSM_RESPONSE_MAX_SIZE],
}

impl NsmMessagePkg {
    fn new(req: Vec<u8>) -> Self {
        NsmMessagePkg {
            req,
            res: [0; NSM_RESPONSE_MAX_SIZE],
        }
    }

    pub fn nsm_message(&mut self) -> NsmMessage {
        NsmMessage {
            request: IoSlice::new(&self.req),
            response: IoSliceMut::new(&mut self.res),
        }
    }
}

/// Encode an NSM `Request` value into a vector.
/// *Argument 1 (input)*: The NSM request.
/// *Returns*: The vector containing the CBOR encoding.
fn nsm_encode_request_to_cbor(request: Request) -> Vec<u8> {
    serde_cbor::to_vec(&request).unwrap()
}

/// Do an `ioctl()` of a given type for a given message.
/// *Argument 1 (input)*: The descriptor to the device file.
/// *Argument 2 (input/output)*: The message to be sent and updated via `ioctl()`.
/// *Returns*: The status of the operation.
fn nsm_ioctl(fd: i32, message: &mut NsmMessage) -> Option<Errno> {
    let status = unsafe {
        ioctl(
            fd,
            request_code_readwrite!(NSM_IOCTL_MAGIC, 0, mem::size_of::<NsmMessage>()),
            message,
        )
    };
    let errno = Errno::last();

    match status {
        // If ioctl() succeeded, the status is the message's response code
        0 => None,

        // If ioctl() failed, the error is given by errno
        _ => Some(errno),
    }
}

fn attestation_request(nonce_size: usize) -> NsmMessagePkg {
    let mut nonce = vec![0u8; nonce_size];
    let mut rng = rand::thread_rng();
    rng.fill_bytes(&mut nonce);

    let request = Request::Attestation {
        user_data: Some(ByteBuf::from("nttp")),
        nonce: Some(ByteBuf::from(nonce)),
        public_key: None,
    };

    let cbor_request = nsm_encode_request_to_cbor(request);
    assert!(
        cbor_request.len() <= NSM_REQUEST_MAX_SIZE,
        "CBOR encoding is too long"
    );
    NsmMessagePkg::new(cbor_request)
}

pub fn criterion_benchmark(c: &mut Criterion) {
    let fd = aws_nsm::driver::nsm_init();
    assert!(fd != -1, "Error opening NSM device!");

    let mut group = c.benchmark_group("Request::Attestation ioctl");
    for size in [4, 8, 16, 32, 64, 128, 256, 512].iter() {
        group.throughput(Throughput::Elements(1));
        group.bench_function(
            BenchmarkId::from_parameter(format!("{:} byte nonce", size)),
            move |b| {
                b.iter_batched_ref(
                    || attestation_request(*size),
                    |nsm_pkg| {
                        let mut nsm_req = nsm_pkg.nsm_message();
                        nsm_ioctl(fd, &mut nsm_req)
                    },
                    BatchSize::SmallInput,
                );
            },
        );
    }
    group.finish();
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
