#
# SPDX-FileCopyrightText: 2019 Kirill Elagin <https://kir.elagin.me/>
# SPDX-FileCopyrightText: 2021 Naïm Favier <n@monade.li>
#
# SPDX-License-Identifier: MPL-2.0 or MIT
#

{ lib }:

let
  inherit (builtins)
    attrValues
    filter
    map
    removeAttrs
    ;
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mapAttrs
    mapAttrsToList
    optionalString
    ;
  inherit (lib)
    mkOption
    mkOptionType
    literalExample
    types
    ;

  inherit (import ./record.nix { inherit lib; }) recordType writeRecord;

  rsubtypes = import ./records { inherit lib; };
  rsubtypes' = removeAttrs rsubtypes [ "SOA" ];

  mergeCustom =
    loc: defs:
    with lib;
    let
      list = getValues defs;
    in
    if length list == 1 then
      head list
    else if all isFunction list then
      x: mergeEqualOption loc (map (def: def // { value = def.value x; }) defs)
    else if all isList list then
      concatLists list
    else if all isAttrs list then
      foldl' lib.mergeAttrs { } list
    else if all isBool list then
      foldl' lib.or false list
    else if all isString list then
      lib.concatStrings list
    else if all isInt list && all (x: x == head list) list then
      head list
    else
      throw "Cannot merge definitions of `${showOption loc}'. Definition values:${showDefs defs}";

  uniqueList =
    listType:
    with lib;
    mkOptionType rec {
      name = "uniqueList";
      description = "";
      merge = loc: defs: lib.lists.unique (listType.merge loc defs);
    };

  coercedToCustom =
    coercedType: coerceFunc: finalType:
    with lib;
    types.mkOptionType rec {
      name = "coercedTo";
      description = "${optionDescriptionPhrase (class: class == "noun") finalType} or ${
        optionDescriptionPhrase (class: class == "noun") coercedType
      } convertible to it";
      check = x: (coercedType.check x && finalType.check (coerceFunc x)) || finalType.check x;
      merge =
        loc: defs:
        let
          coerceVal = val: coerceFunc val;
        in
        finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
      emptyValue = finalType.emptyValue;
      getSubOptions = finalType.getSubOptions;
      getSubModules = finalType.getSubModules;
      substSubModules = m: coercedToCustom coercedType coerceFunc (finalType.substSubModules m);
      typeMerge = t1: t2: null;
      functor = (defaultFunctor name) // {
        wrapped = finalType;
      };
      nestedTypes.coercedType = coercedType;
      nestedTypes.finalType = finalType;
    };

  toStringType = mkOptionType {
    name = "toStringType";
    description = "";
    check = value: true;
    merge = mergeCustom;
  };

  subzoneOptions =
    {
      subdomains = mkOption {
        type = types.attrsOf subzone;
        default = { };
        example = {
          www = {
            A = [ { address = "1.1.1.1"; } ];
          };
          staging = {
            A = [ { address = "1.0.0.1"; } ];
          };
        };
        description = "Records for subdomains of the domain";
      };
    }
    // mapAttrs (
      n: t:
      mkOption rec {
        type = uniqueList (types.listOf (recordType t));
        default = [ ];
        # example = [ t.example ];  # TODO: any way to auto-generate an example for submodule?
        description = "List of ${n} records for this zone/subzone";
      }
    ) rsubtypes';

  subzone = types.submodule { options = subzoneOptions; };

  writeSubzone =
    name: zone:
    let
      groupToString = pseudo: subt: concatMapStringsSep "\n" (writeRecord name subt) (zone."${pseudo}");
      groups = mapAttrsToList groupToString rsubtypes';
      groups' = filter (s: s != "") groups;

      writeSubzone' = subname: writeSubzone "${subname}.${name}";
      sub = concatStringsSep "\n\n" (mapAttrsToList writeSubzone' zone.subdomains);
    in
    concatStringsSep "\n\n" groups' + optionalString (sub != "") ("\n\n" + sub);

  zone = types.submodule (
    { name, ... }:
    {
      options = {
        TTL = mkOption {
          type = types.ints.unsigned;
          default = 24 * 60 * 60;
          example = literalExample "60 * 60";
          description = "Default record caching duration. Sets the $TTL variable";
        };
        SOA = mkOption rec {
          type = recordType rsubtypes.SOA;
          example = {
            ttl = 24 * 60 * 60;
          } // type.example;
          description = "SOA record";
        };
        __toString = mkOption {
          readOnly = false;
          visible = false;
          type = toStringType;
        };
      } // subzoneOptions;

      config = {
        __toString =
          zone@{ TTL, SOA, ... }:
          ''
            $TTL ${toString TTL}

            ${writeRecord name rsubtypes.SOA SOA}

            ${writeSubzone name zone}
          '';
      };
    }
  );

in

{
  inherit zone;
  inherit subzone;
}
