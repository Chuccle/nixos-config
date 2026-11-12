{
  flake.nixosModules.kernel-hardening = {
    boot.kernel.sysctl = {
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "fs.suid_dumpable" = 0;
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.perf_event_paranoid" = 3;
      "kernel.sysrq" = 0;
      "kernel.unprivileged_bpf_disabled" = 1;
    };

    boot.kernelParams = [
      "randomize_kstack_offset=on"
      "vsyscall=none"
      "slab_nomerge"
      "page_alloc.shuffle=1"
    ];
  };
}
