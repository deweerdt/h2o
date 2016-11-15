use strict;
use warnings;
use Test::More;
use t::Util;


ok(safe_empty_port_check() == 0, "No fd leaked");
