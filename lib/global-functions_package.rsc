# Global Functions | Package
# =========================================================
# ALL global functions follows upper camel case.
#
# USE as your wish

:local metaInfo {
    "name"="global-functions.package";
    "version"="0.0.1";
    "description"="global functions for package operation";
    "global"=true;
};


# $FindPackage
# args: <str>                   <package name>
# return: <id> or nil           id of package in /system script
:global FindPackage do={
    # global declare
    :global Replace;
    :global IsEmpty;
    :global Nil;
    # replace
    :local pkgName $1;
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :return $idList;
}


# $ValidatePackageContent
# args: <array->str>            package content array
# args: <array->str>            validate array
# return: <bool>                validate flag
:global ValidatePackageContent do={
    :global InKeys;
    :global IsArray;
    :global ReadOption;
    :global TypeofStr;
    # check meta
    :local metaList ($1->"metaInfo");
    :if (![$IsArray $metaList]) do={
        :log warning "Global.ValidatePackageContent: metaInfo not found in this package";
        :return false;
    }
    # check validate array
    :local va $2;
    :if (![$IsArray $va]) do={
        :error "Global.ValidatePackageContent: \$2 should be a validate array";
    }
    # va: check meta name
    :if ([$InKeys "name" $va]) do={
        :if (($metaList->"name") != ($va->"name")) do={
            :log warning "Global.ValidatePackageContent: mismatch package name: $pkgName";
            :return false;
        }
    }
    # va: check meta type
    :if ([$InKeys "type" $va]) do={
        :local metaType [$ReadOption ($metaList->"type") $TypeofStr "code"];
        :if ($metaType != ($va->"type")) do={
            :log warning "Global.ValidatePackageContent: mismatch package type: $pkgName";
            :return false;
        }
    }
    # va: check meta url
    :if ([$InKeys "url" $va]) do={
        :local metaUrl [$ReadOption ($metaList->"url") $TypeofStr ""];
        :if ($metaUrl = "") do={
            :log warning "Global.ValidatePackageContent: url not found in meta: $pkgName";
            :return false;
        }
    }
    :return true;
}


# $ValidatePackage
# args: <str>                   package name
# args: <array->str>            validate array
# return: <bool>                validate flag
:global ValidatePackage do={
    # global declare
    :global Print;
    :global IsArray;
    :global IsEmpty;
    :global Replace;
    :global NewArray;
    :global ReadOption;
    :global TypeofArray;
    :global ValidatePackageContent;
    # local
    :local pkgName $1;
    :local va [$ReadOption $2 $TypeofArray [$NewArray]];
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :if ([$IsEmpty $idList]) do={
        :error "Global.ValidatePackage: script \"$fileName\" not found"
    }
    # parse code and get result;
    :local pSource [:parse [/system script get ($idList->0) source]];
    :local pkg [$pSource ];
    :set ($va->"name") $pkgName;
    :local vf [$ValidatePackageContent $pkg $va];
    :return $vf;
}


# $GetSource
# args: <str>                   <package name>
# return: <str>                 source of package  
:global GetSource do={
    # global declare
    :global Replace;
    :global IsEmpty;
    # replace
    :local pkgName $1;
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :if ([$IsEmpty $idList]) do={
        :error "Global.GetSource: script \"$fileName\" not found"
    }
    # get source;
    :local pSource [/system script get ($idList->0) source];
    :return $pSource;
}


# $GetMeta
# args: <str>                   find by <package name>
# opt kwargs: ID=<id>           find by id
# opt kwargs: VA=<array->str>   validate array
# return: <array->str>          meta named array 
:global GetMeta do={
    # global declare
    :global IsNil;
    :global IsNothing;
    :global Replace;
    :global IsEmpty;
    :global ReadOption;
    :global TypeofID;
    :global TypeofStr;
    :global TypeofArray;
    :global ValidatePackageContent;
    # check
    :local tID;
    :local pkgName [$ReadOption $1 $TypeofStr ""];
    :local pID [$ReadOption $ID $TypeofID ];
    :local pVA [$ReadOption $VA $TypeofArray ];
    :if ($pkgName != "") do={
        :local fileName [$Replace $pkgName "." "_"];
        :local idList [/system script find name=$fileName];
        :if ([$IsEmpty $idList]) do={
            :error "Global.GetMeta: script \"$fileName\" not found"
        } else {
            :set tID ($idList->0);
        }
    }
    :if (![$IsNil $pID]) do={
        :set tID $pID;
        :set pkgName [$Replace [/system script get $pID name] "_" "."];
    }
    :if ([$IsNothing $tID]) do={
        :error "Global.GetMeta: need either <name> or <id>";
    }
    # parse code and get result;
    :local pSource [:parse [/system script get $tID source]];
    :local pkg [$pSource ];
    :local va {"name"=$pkgName};
    :if (![$IsNil $pVA]) do={
        :foreach k,v in $pVA do={
            :set ($va->$k) $v;
        }
    }
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.GetMeta: could not validate target package";
    }
    :return ($pkg->"metaInfo");
}


# $GetFunc
# args: <str>                   <package name>.<func name>
# return: <code>                target function  
:global GetFunc do={
    # global declare
    :global RSplit;
    :global Replace;
    :global IsEmpty;
    :global ValidatePackageContent;
    # split package & function
    :local splitted [$RSplit $1 "." 1];
    :local pkgName ($splitted->0);
    :local funcName ($splitted->1);
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :if ([$IsEmpty $idList]) do={
        :error "Global.GetFunc: script \"$fileName\" not found"
        :return "";
    }
    # parse code and get result;
    :local pSource [:parse [/system script get ($idList->0) source]];
    :local pkg [$pSource ];
    :local va {"name"=$pkgName;"type"="code"};
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.GetFunc: could not validate target package";
    }
    :return ($pkg->$funcName);
}


# $GetConfig
# args: <str>                   <package name>
# return: <array->var>          config named array      
:global GetConfig do={
    # global declare
    :global RSplit;
    :global Replace;
    :global IsEmpty;
    :global ValidatePackageContent;
    # replace
    :local pkgName $1;
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :if ([$IsEmpty $idList]) do={
        :error "Global.GetConfig: script \"$fileName\" not found"
        :return "";
    }
    # parse code and get result;
    :local pSource [:parse [/system script get ($idList->0) source]];
    :local pkg [$pSource ];
    :local va {"name"=$pkgName;"type"="config"};
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.GetConfig: could not validate target package";
    }
    :return $pkg;
}


# $GetEnv
# args: <str>                   <package name>
# return: <array->var>          env named array      
:global GetEnv do={
    # global declare
    :global RSplit;
    :global Replace;
    :global IsEmpty;
    :global ValidatePackageContent;
    # replace
    :local pkgName $1;
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :if ([$IsEmpty $idList]) do={
        :error "Global.GetEnv: script \"$fileName\" not found"
        :return "";
    }
    # parse code and get result;
    :local pSource [:parse [/system script get ($idList->0) source]];
    :local pkg [$pSource ];
    :local va {"name"=$pkgName;"type"="env"};
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.GetEnv: could not validate target package";
    }
    :return $pkg;
}


# $PrintPackageInfo
# args: <str>                   <package name>
:global PrintPackageInfo do={
    :local metaInfo [$GetPackageInfo package=$package];
    :put ("Package: " . $metaInfo->"name");
    :put ("Version: " . $metaInfo->"version");
    :put ("Description: " . $metaInfo->"description");
    :put ("FunctionList: " . [:len ($metaInfo->"functionList")]);
    foreach function in=($metaInfo->"functionList") do={
        :put ("    " . $function);
    }
    :return "";
}


# $DumpVar
# dump a variable into string.
# args: <str>                       <variable name>
# args: <var>                       variable
# opt kwargs: Indent=<str>          indent string
# opt kwargs: StartIndent=<num>     start indent string count
# opt kwargs: Output=<str>          output format: str, array
# opt kwargs: Return=<bool>         default true
:global DumpVar do={
    # global declare
    :global NewArray;
    :global ReadOption;
    :global Extend;
    :global Join;
    :global IsEmpty;
    :global IsStr;
    :global IsArray;
    :global StartsWith;
    :global TypeofArray;
    :global TypeofStr;
    :global TypeofNum;
    :global TypeofBool;
    # read option
    :local indent [$ReadOption $Indent $TypeofStr "    "];
    :local cursor [$ReadOption $StartIndent $TypeofNum 0];
    :local pOutput [$ReadOption $Output $TypeofStr "str"];
    :local pReturn [$ReadOption $Return $TypeofBool true];
    # set start indent
    :local si "";
    :for i from=1 to=$cursor step=1 do={
        :set si ($si . $indent);
    }
    # init LSL
    :local LSL [$NewArray ];
    :local flagType false;
    # str
    :if ([$IsStr $2]) do={
        :set ($LSL->0) "$si:local $1 \"$2\";";
        :set flagType true;
    }
    # array
    :if ([$IsArray $2]) do={
        :set ($LSL->0) "$si:local $1 {";
        # queue structure
        # {
        #     [<father's line number>, <line number>, array];
        #     [0, 0, a1];
        #     [0, 3, a2];
        #     [0, 5, a3];
        # }   
        :local flag true;
        :local queue [$NewArray ];
        :local queueNext [$NewArray ];
        :local sq {1; 0; $2};
        :set ($queueNext->0) $sq;
        :local deltaLN 0;
        :while ($flag) do={
            :if ([$IsEmpty $queueNext]) do={
                :set flag false;
            } else {
                :set queue $queueNext;
                :set queueNext [$NewArray ];
                :set deltaLN 0;
                :foreach node in $queue do={
                    :local fatherLN ($node->0);
                    :local selfLN ($node->1);
                    :local subLSL [$NewArray ];
                    :foreach k,v in ($node->2) do={
                        # make indent
                        :local ind "";
                        :for i from=0 to=$cursor do={
                            :set ind ($ind . $indent);
                        }
                        # make key
                        :local ks "";
                        :if ([:typeof $k] = $TypeofNum) do={
                            :set ks "";
                        } else {
                            :set ks "\"$k\"="
                        }
                        # type specific
                        :local fT false;
                        :if ([:typeof $v] = $TypeofArray) do={
                            # add starting brace
                            :local lineStr "$ind$ks{";
                            :set ($subLSL->[:len $subLSL]) $lineStr;
                            :local a [$NewArray ];
                            :set ($a->0) ($fatherLN + $selfLN + $deltaLN);
                            :set ($a->1) [:len $subLSL];
                            :set ($a->2) $v;
                            :set ($queueNext->[:len $queueNext]) $a;
                            # add closing brace
                            :local lineStr "$ind};";
                            :set ($subLSL->[:len $subLSL]) $lineStr;
                            :set fT true;
                        };
                        :if ([:typeof $v] = $TypeofStr) do={
                            :local lineStr;
                            :local noquote "noquote:";
                            :if ([$StartsWith $v $noquote]) do={
                                :local vs [:pick $v [:len $noquote] [:len $v]];
                                :set lineStr "$ind$ks$vs;";
                            } else {
                                :set lineStr "$ind$ks\"$v\";";
                            }
                            :set ($subLSL->[:len $subLSL]) $lineStr;
                            :set fT true;
                        }
                        # rest of type
                        :if ($fT = false) do={
                            :local lineStr "$ind$ks$v;";
                            :set ($subLSL->[:len $subLSL]) $lineStr;
                        }

                    }
                    # extend here
                    :set LSL [$Extend $LSL $subLSL ($deltaLN + $fatherLN + $selfLN)];
                    :set deltaLN ($deltaLN + [:len $subLSL]);
                }
                :set cursor ($cursor + 1);
            }
        }
        :set ($LSL->[:len $LSL]) "$si}";
        :set flagType true;
    }
    # the rest type
    :if ($flagType = false) do={
        :set ($LSL->0) "$si:local $1 $2;";
    }
    # handle return
    :if ($pReturn = true) do={
        :set ($LSL->[:len $LSL]) ":return \$$1;";
    }
    :if ($pOutput = "array") do={
        :return $LSL;
    }
    # join into string
    :local LS [$Join ("\r\n") $LSL];
    :return $LS;
}


# $LoadVar
# load a string into variable.
# args: <str>                       <variable>
:global LoadVar do={
    :local varFunc [:parse $1];
    :local var [$varFunc ];
    :return $var;
}


# $CreateConfig
# create a new configuration package.
# args: <str>                   config name
# args: <array->str>            config array
# args: <array->str>            array of var
# opt kwargs: Output=<str>      output format: file(default), str, array
# opt kwargs: Owner=<str>       script owner
# return: <str>                 string of config package
:global CreateConfig do={
    # global declare
    :global IsStr;
    :global IsArray;
    :global IsEmpty;
    :global Join;
    :global DumpVar;
    :global NewArray;
    :global TypeofStr;
    :global Replace;
    :global ReadOption;
    :global ScriptLengthLimit;
    :global Print;
    # check params
    :if (![$IsStr $1]) do={
        :error "Global.CreateConfig: \$1 should be str";
    }
    :if (![$IsArray $2]) do={
        :error "Global.CreateConfig: \$2 should be array";
    }
    # local
    :local pConfig $2;
    :local pOutput [$ReadOption $Output $TypeofStr "file"];
    :local pOwner [$ReadOption $Owner $TypeofStr ""];
    :local LSL [$NewArray ];
    # dump meta
    # TODO: better clock info
    :local clock [/system clock print as-value];
    :local date ($clock->"date");
    :local time ($clock->"time");
    :local meta {
        "name"=$1;
        "type"="config";
        "created_at"="$date $time";
        "last_modify"="$date $time";
    };
    :set LSL ($LSL, [$DumpVar "metaInfo" $meta Output="array" Return=false]);
    :set ($LSL->[:len $LSL]) "";
    # dump additions
    :if ([$IsArray $3]) do={
        :foreach k,v in $3 do={
            :local sLSL [$DumpVar $k $v Output="array" Return=false];
            :set LSL ($LSL, $sLSL);
            :set ($LSL->[:len $LSL]) "";
        };
    };
    # dump config
    :set ($pConfig->"metaInfo") "noquote:\$metaInfo"
    :set LSL ($LSL, [$DumpVar "config" $pConfig Output="array"]);
    :set ($LSL->[:len $LSL]) "";
    # output
    :if ($pOutput = "array") do={
        :return $LSL;
    }
    # join
    :local result [$Join ("\r\n") $LSL];
    # script length
    :if ([:len $result] >= $ScriptLengthLimit) do={
        :error "Global.CreateConfig: configuration file length reachs 30,000 characters limit, try split it";
    }
    :if ($pOutput = "str") do={
        :return $result;
    }
    # make file
    :if ($pOutput = "file") do={
        :local fileName [$Replace $1 "." "_"];
        :if ([$IsEmpty [/system script find name=$fileName]]) do={
            :if ($pOwner = "") do={
                /system script add name=$fileName source=$result;
            } else {
                /system script add name=$fileName source=$result owner=$pOwner;
            }
        } else {
            :error "Global.CreateConfig: same configuration file already exist!";
        }
    }
}


# $UpdateConfig
# update configure with target array.
# args: <str>                   <package name>
# args: <array>                 config array
# opt kwargs: Output=<str>      output format: file(default), str, array
:global UpdateConfig do={
    # global declare
    :global GetConfig;
    :global IsArray;
    :global DumpVar;
    :global Join;
    :global FindPackage;
    :global TypeofStr;
    :global ReadOption;
    :global ScriptLengthLimit;
    :global NewArray;
    :global Replace;
    # local
    :local pkgName $1;
    :local pOutput [$ReadOption $Output $TypeofStr "file"];
    :local fileName [$Replace $pkgName "." "_"];
    :local config [$GetConfig $pkgName];
    :local Owner [/system script get [/system script find name=$fileName] owner];
    :local LSL [$NewArray ];
    :local configArray {
        "metaInfo"="noquote:\$metaInfo";
    };
    :if (![$IsArray $2]) do={
        :error "Global.UpdateConfig: \$2 should a k,v array";
    }
    # update meta
    # TODO: better clock info
    :local clock [/system clock print as-value];
    :local date ($clock->"date");
    :local time ($clock->"time");
    :local meta ($config->"metaInfo");
    :set ($meta->"last_modify") "$date $time";
    :set LSL ($LSL, [$DumpVar "metaInfo" $meta Output="array" Return=false]);
    :set ($LSL->[:len $LSL]) "";
    # update by input
    :foreach k,v in $2 do={
        :set ($config->$k) $v;
    }
    # update addition array
    :foreach k,v in $config do={
        :if ([$IsArray $v]) do={
            :if ($k != "metaInfo") do={
                :set ($configArray->$k) "noquote:\$$k";
                :set LSL ($LSL, [$DumpVar $k $v Output="array" Return=false]);
                :set ($LSL->[:len $LSL]) "";
            }
        } else {
            :set ($configArray->$k) $v;
        }
    }
    # update config array
    :set LSL ($LSL, [$DumpVar "config" $configArray Output="array"]);
    :set ($LSL->[:len $LSL]) "";
    # output array
    :if ($pOutput = "array") do={
        :return $LSL;
    }
    # join
    :local result [$Join ("\r\n") $LSL];
    # script length
    :if ([:len $result] >= $ScriptLengthLimit) do={
        :error "Global.UpdateConfig: configuration file length reachs 30,000 characters limit, try split it";
    }
    # output str
    :if ($pOutput = "str") do={
        :return $result;
    }
    # output file
    /system script set [$FindPackage $pkgName] source=$result owner=$Owner;
}


# $UpdateConfigDep
# update configure with target array.
# args: <str>                   <package name>
# args: <array>                 values need update
:global UpdateConfigDep do={
    # global declare
    :global GetSource;
    :global GetConfig;
    :global IsEmpty;
    :global IsNothing;
    :global Split;
    :global Join;
    :global Strip;
    :global Replace;
    :global DumpVar;
    :global NewArray;
    :global TypeofStr;
    :global TypeofArray;
    :global ScriptLengthLimit;
    :global Print;
    # local
    :local pkgName $1;
    :local fileName [$Replace $pkgName "." "_"];
    :local config [$GetConfig $pkgName];
    :local pkgStr [$GetSource $pkgName];
    :local flag true;
    # target scope
    :local findLineS ":local config {";
    :local pLines [$Split $pkgStr ("\n")];
    # find target scope start position
    :local posMax [:len $pLines];
    :local posLS 0;
    :local pLine;
    :set flag true;
    :while ($flag) do={
        :if ($posLS < $posMax) do={
            :set pLine ($pLines->$posLS);
            # strip
            :if ([$Strip $pLine Mode="r"] = $findLineS) do={
                :set flag false;
            } else {
                :set posLS ($posLS + 1);
            }
        } else {
            :error "Global.UpdateConfig: scope start position not found";
        }
    }
    # find end position
    # TODO: need a better way to find closing brace 
    :local findLineE "}";
    :local posLE $posLS;
    :set flag true;
    :while ($flag) do={
        :if ($posLE < $posMax) do={
            :set pLine ($pLines->$posLE);
            # strip
            :if ([$Strip $pLine Mode="r"] = $findLineE) do={
                :set flag false;
            } else {
                :set posLE ($posLE + 1);
            }
        } else {
            :error "Global.UpdateConfig: scope end position not found";
        }
    }
    # update config array
    :foreach k,v in $2 do={
        :set ($config->$k) $v;
    }
    # dump it
    :local LSL [$DumpVar "config" $config Output="array" Return=false];
    # replace exist scope
    :local resultList ([:pick $pLines 0 $posLS], $LSL, [:pick $pLines ($posLE + 1) $posMax]);
    :local result [$Join ("\r\n") $resultList];
    # script length check
    :if ([:len $result] >= $ScriptLengthLimit) do={
        :error "Global.UpdateConfig: configuration file length reachs 30,000 characters limit, try split it"
    }
    # set source
    :local idList [/system script find name=$fileName];
    :if ([$IsEmpty $idList]) do={
        :error "Global.UpdateConfig: script \"$fileName\" not found"
    }
    # parse code and get result;
    /system script set numbers=($idList->0) source=$result;
    :return "";
}


# package info
:local package {
    "metaInfo"=$metaInfo;
}
:return $package;
