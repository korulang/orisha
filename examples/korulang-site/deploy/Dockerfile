# korulang.org, served by Orisha.
#
# The binary is statically linked against musl and the whole website is embedded
# inside it at compile time, so there is nothing else to put in the image — no
# libc, no shell, no site directory. `FROM scratch` is not a flourish here, it is
# the honest contents.
#
# Build the binary first (it is not built here — cross-compiling Koru needs the
# toolchain, not a container):
#
#   cd ~/src/korulang_org && pnpm build:static
#   cd ~/src/orisha/examples/korulang-site && koruc main.kz --build=linux
#   docker build -f deploy/Dockerfile -t korulang-site .
FROM scratch

COPY a.out /server

EXPOSE 3000

ENTRYPOINT ["/server"]
