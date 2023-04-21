mod aws_nsm {
    pub use aws_nitro_enclaves_nsm_api::*;
}
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use libc::ioctl;
use nix::errno::Errno;
use nix::request_code_readwrite;
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

/*
pub fn simple_attestation(fd: i32, nsm_req: aws_nsm::api::Request) -> aws_nsm::api::Response {
    let resp = aws_nsm::driver::nsm_process_request(fd, nsm_req);
    print!("{resp:?}");
    resp
}
*/

pub fn criterion_benchmark(c: &mut Criterion) {
    env_logger::init();

    let fd = aws_nsm::driver::nsm_init();
    assert!(fd != -1, "Error opening NSM device!");

    c.bench_function("attest", |b| {
        b.iter(|| {
            let cbor_request:&[u8] = b"123 456";

            let mut cbor_response: [u8; NSM_RESPONSE_MAX_SIZE] = [0; NSM_RESPONSE_MAX_SIZE];
            let mut message = NsmMessage {
                request: IoSlice::new(&cbor_request),
                response: IoSliceMut::new(&mut cbor_response),
            };
            nsm_ioctl(fd, black_box(&mut message));
            /*
                        let nsm_req = aws_nsm::api::Request::Attestation {
                            user_data: None,
                            nonce: None,
                            public_key: None,
                        };
                        simple_attestation(fd, black_box(nsm_req))
            */
        })
    });
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
