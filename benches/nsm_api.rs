// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use rand::RngCore;
mod aws_nsm {
    pub use aws_nitro_enclaves_nsm_api::*;
}
use criterion::{criterion_group, criterion_main, BatchSize, BenchmarkId, Criterion, Throughput};
use serde_bytes::ByteBuf;

fn attestation_request(nonce_size: usize) -> aws_nsm::api::Request {
    let mut nonce = vec![0u8; nonce_size];
    let mut rng = rand::thread_rng();
    rng.fill_bytes(&mut nonce);

    aws_nsm::api::Request::Attestation {
        user_data: Some(ByteBuf::from("nttp")),
        nonce: Some(ByteBuf::from(nonce)),
        public_key: None,
    }
}

pub fn request_attestation(c: &mut Criterion) {
    let fd = aws_nsm::driver::nsm_init();
    assert!(fd != -1, "Error opening NSM device!");

    let mut group = c.benchmark_group("Request::Attestation");
    for size in [4, 8, 16, 32, 64, 128, 256, 512].iter() {
        group.throughput(Throughput::Elements(1));
        group.bench_function(
            BenchmarkId::from_parameter(format!("{:} byte nonce", size)),
            move |b| {
                b.iter_batched(
                    || attestation_request(*size),
                    |nsm_req| aws_nsm::driver::nsm_process_request(fd, nsm_req),
                    BatchSize::SmallInput,
                );
            },
        );
    }
    group.finish();
}

pub fn get_random(c: &mut Criterion) {
    let fd = aws_nsm::driver::nsm_init();
    assert!(fd != -1, "Error opening NSM device!");

    let mut group = c.benchmark_group("Request::GetRandom");
    group.throughput(Throughput::Elements(1));
    group.bench_function("Request::GetRandom", |b| {
        b.iter_batched(
            || aws_nsm::api::Request::GetRandom {},
            |nsm_req| aws_nsm::driver::nsm_process_request(fd, nsm_req),
            BatchSize::SmallInput,
        )
    });
    group.finish();
}

criterion_group!(benches, request_attestation, get_random);
criterion_main!(benches);
