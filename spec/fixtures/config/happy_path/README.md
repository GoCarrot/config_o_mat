The expected final merged output of this config is

log_level: debug

services:
  test0:
    systemd_unit: test0
    restart_mode: flip_flop
    templates:
      - templ0
      - templ1
      - templ2
  test1:
    systemd_unit: test1
    restart_mode: restart
    templates:
      - templ0
      - templ2
  test2:
    systemd_unit: test2
    restart_mode: restart
    templates:
      - templ0

templates:
  templ0:
    src: foo2.conf
    dst: foo.conf
  templ1:
    src: bar.conf
    dst: bar.conf
  templ2:
    src: baz.conf
    dst: baz.conf
  templ3:
    src: 3.conf
    dst: 3.conf

profiles:
  source0:
    application: test
    environment: test
    profile: test
  source1:
    application: bar
    environment: test
    profile: test
  source2:
    application: baz
    environment: baz
    profile: other
