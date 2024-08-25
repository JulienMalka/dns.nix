#
# SPDX-FileCopyrightText: 2019 Kirill Elagin <https://kir.elagin.me/>
#
# SPDX-License-Identifier: MPL-2.0 or MIT
#

# RFC 2782

{ lib }:

let
  inherit (lib) dns mkOption types;

in

{
  rtype = "TLSA";
  options = {
    usage = mkOption {
      type = types.ints.u16;
      default = 0;
      example = 0;
    };
    selector = mkOption {
      type = types.ints.u16;
      default = 0;
      example = 0;
    };
    matching-type = mkOption {
      type = types.ints.u16;
      default = 0;
      example = 0;
    };
    association-data = mkOption {
      type = types.str;
      example = "foobar";
    };
  };
  dataToString =
    data:
    with data;
    "${toString usage} ${toString selector} ${toString matching-type} ${association-data}";
}
