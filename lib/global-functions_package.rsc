#!rsc by RouterOS
# ===================================================================
# |     Global Functions     |   global-functions.package
# ===================================================================
# ALL global functions follows upper camel case.
# global functions for package operation
#
# Copyright (c) 2020-2021 detavern <detavern@live.com>
# https://github.com/Detavern/rspm/blob/master/LICENSE.md
#
:local metaInfo {
    "name"="global-functions.package";
    "version"="0.3.1";
    "description"="global functions for package operation";
    "global"=true;
    "global-functions"={
        "FindPackage";
        "ValidatePackageContent";
        "ValidatePackage";
        "GetSource";
        "GetMeta";
        "ParseMetaSafe";
        "GetMetaSafe";
        "GetEnv";
        "PrintPackageInfo";
        "LoadPackage";
        "GetFunc";
        "DumpVar";
        "LoadVar";
        "SetGlobalVar";
        "LoadGlobalVar";
        "UnsetGlobalVar";
    };
};


# $FindPackage
# args: <str>                   <package name>
# return: <id> or nil           id of package in /system script
:global FindPackage do={
    # global declare
    :global Replace;
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
        :log warning "Global.Package.ValidatePackageContent: metaInfo not found in this package";
        :return false;
    }
    # check validate array
    :local va $2;
    :if (![$IsArray $va]) do={
        :error "Global.Package.ValidatePackageContent: \$2 should be a validate array";
    }
    # va: check meta name
    :if ([$InKeys "name" $va]) do={
        :if (($metaList->"name") != ($va->"name")) do={
            :log warning "Global.Package.ValidatePackageContent: mismatch package name: $pkgName";
            :return false;
        }
    }
    # va: check meta type
    :if ([$InKeys "type" $va]) do={
        :local metaType [$ReadOption ($metaList->"type") $TypeofStr "code"];
        :if ($metaType != ($va->"type")) do={
            :log warning "Global.Package.ValidatePackageContent: mismatch package type: $pkgName";
            :return false;
        }
    }
    # va: check meta url
    :if ([$InKeys "url" $va]) do={
        :local metaUrl [$ReadOption ($metaList->"url") $TypeofStr ""];
        :if ($metaUrl = "") do={
            :log warning "Global.Package.ValidatePackageContent: url not found in meta: $pkgName";
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
        :error "Global.Package.ValidatePackage: script \"$fileName\" not found"
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
        :error "Global.Package.GetSource: script \"$fileName\" not found"
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
            :error "Global.Package.GetMeta: script \"$fileName\" not found"
        } else {
            :set tID ($idList->0);
        }
    }
    :if (![$IsNil $pID]) do={
        :set tID $pID;
        :set pkgName [$Replace [/system script get $pID name] "_" "."];
    }
    :if ([$IsNothing $tID]) do={
        :error "Global.Package.GetMeta: need either <name> or <id>";
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
        :error "Global.Package.GetMeta: could not validate target package";
    }
    :return ($pkg->"metaInfo");
}


# $ParseMetaSafe
# cut off the code snippet of metaInfo, parse it and return
# args: <str>                   code string
# return: <array->str>          meta named array 
:global ParseMetaSafe do={
    # global declare
    :global IsNil;
    :global IsStr;
    # local
    :if (![$IsStr $1]) do={
        :error "Global.Package.ParseMetaSafe: \$1 should be string";
    }
    :local source $1;
    :local pt ":local metaInfo {";
    :local start [:find $source $pt];
    :if ([$IsNil $start]) do={
        :error "Global.Package.ParseMetaSafe: could not find metaInfo";
    }
    :local cursor ($start + [:len $pt]);
    :local count 1;
    :local flagQuote false;
    :local ch;
    :while ($count != 0 and $cursor < [:len $source]) do={
        :set ch [:pick $source $cursor];
        :if ($flagQuote) do={
            :if ($ch = "\\") do={
                :set cursor ($cursor + 1);
            }
            :if ($ch = "\"") do={
                :set flagQuote false;
            }
            :if ($ch ~ "[\$]") do={
                :error "Global.Package.ParseMetaSafe: pos: $cursor, unsafe char: $ch."
            }
        } else {
            :if ($ch = "\"") do={
                :set flagQuote true;
            }
            :if ($ch ~ "[][\$:]") do={
                :error "Global.Package.ParseMetaSafe: pos: $cursor, unsafe char: $ch."
            }
            :if ($ch = "{") do={
                :set count ($count + 1);
            }
            :if ($ch = "}") do={
                :set count ($count - 1);
            }
        }
        :set cursor ($cursor + 1);
    }
    :local snippet ([:pick $source $start $cursor] . "\r\n:return \$metaInfo;");
    :local cmd [:parse $snippet];
    :local metaInfo [$cmd];
    :return $metaInfo;
}


# $GetMetaSafe
# get meta info by parsing the cutted code snippet of metaInfo
# args: <str>                   find by <package name>
# opt kwargs: ID=<id>           find by id
# opt kwargs: VA=<array->str>   validate array
# return: <array->str>          meta named array 
:global GetMetaSafe do={
    # global declare
    :global IsNil;
    :global IsNothing;
    :global Replace;
    :global IsEmpty;
    :global ReadOption;
    :global TypeofID;
    :global TypeofStr;
    :global TypeofArray;
    :global ParseMetaSafe;
    :global NewArray;
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
            :error "Global.Package.GetMetaSafe: script \"$fileName\" not found"
        } else {
            :set tID ($idList->0);
        }
    }
    :if (![$IsNil $pID]) do={
        :set tID $pID;
        :set pkgName [$Replace [/system script get $pID name] "_" "."];
    }
    :if ([$IsNothing $tID]) do={
        :error "Global.Package.GetMetaSafe: need either <name> or <id>";
    }
    # manually parse code and get result;
    :local pkg [$NewArray ];
    :local source [/system script get $tID source];
    :set ($pkg->"metaInfo") [$ParseMetaSafe $source];
    # va
    :local va {"name"=$pkgName};
    :if (![$IsNil $pVA]) do={
        :foreach k,v in $pVA do={
            :set ($va->$k) $v;
        }
    }
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.Package.GetMetaSafe: could not validate target package";
    }
    :return ($pkg->"metaInfo");
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
        :error "Global.Package.GetEnv: script \"$fileName\" not found"
        :return "";
    }
    # parse code and get result;
    :local pSource [:parse [/system script get ($idList->0) source]];
    :local pkg [$pSource ];
    :local va {"name"=$pkgName;"type"="env"};
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.Package.GetEnv: could not validate target package";
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


# $LoadPackage
# args: <str>                   <package name>
:global LoadPackage do={
    # global declare
    :global TypeofStr;
    :global ReadOption;
    :global Replace;
    :global IsEmpty;
    # load
    :local pkgName [$ReadOption $1 $TypeofStr ""];
    :if ($pkgName != "") do={
        :local fileName [$Replace $pkgName "." "_"];
        :local idList [/system script find name=$fileName];
        :if ([$IsEmpty $idList]) do={
            :error "Global.Package.LoadPackage: script \"$fileName\" not found"
        } else {
            /system script run $idList;
        }
    } else {
        :error "Global.Package.LoadPackage: \$1 is empty";
    }
}


# $GetFunc
# args: <str>                   <package name>.<func name>
# return: <code>                target function
:global GetFunc do={
    # global declare
    :global RSplit;
    :global Replace;
    :global IsArrayN;
    :global IsNil;
    :global IsNothing;
    :global IsNum;
    :global FindPackage;
    :global GlobalCacheFuncGet;
    :global GlobalCacheFuncPut;
    :global ValidatePackageContent;
    # local
    :local pkg;
    :local func;
    # try global cache
    :set func [$GlobalCacheFuncGet $1];
    :if (![$IsNil $func]) do={
        :return $func;
    }
    # split package & function
    :local splitted [$RSplit $1 "." 1];
    :local pkgName ($splitted->0);
    :local funcName ($splitted->1);
    :local fileName [$Replace $pkgName "." "_"];
    :local idList [/system script find name=$fileName];
    :if (![$IsArrayN $idList]) do={:error "Global.Package.GetFunc: script \"$fileName\" not found"};
    # parse code and get result
    :local pSource [:parse [/system script get ($idList->0) source]];
    :set pkg [$pSource ];
    :local va {"name"=$pkgName;"type"="code"};
    if (![$ValidatePackageContent $pkg $va]) do={
        :error "Global.Package.GetFunc: could not validate target package";
    }
    # get func from package
    :set func ($pkg->$funcName);
    :if ([$IsNothing $func]) do={
        :error "Global.Package.GetFunc: function $funcName not found in package.";
    } else {
        :local idList [$FindPackage "config.rspm"];
        :if ([$IsArrayN $idList]) do={
            # put into global cache
            [$GlobalCacheFuncPut $1 $func];
        }
    }
    :return $func;
}


# $DumpVar
# dump a variable into string.
# args: <str>                       <variable name>
# args: <var>                       variable
# opt kwargs: Indent=<str>          indent string
# opt kwargs: StartIndent=<num>     start indent string count
# opt kwargs: Output=<str>          output format: str, array
# opt kwargs: Global=<bool>         default false, use global declaration if true
# opt kwargs: Return=<bool>         default true
:global DumpVar do={
    # global declare
    :global NewArray;
    :global ReadOption;
    :global Extend;
    :global Join;
    :global IsStr;
    :global IsArray;
    :global IsArrayN;
    :global StartsWith;
    :global TypeofArray;
    :global TypeofStr;
    :global TypeofNum;
    :global TypeofBool;
    # read option
    :local indent [$ReadOption $Indent $TypeofStr "    "];
    :local cursor [$ReadOption $StartIndent $TypeofNum 0];
    :local pOutput [$ReadOption $Output $TypeofStr "str"];
    :local pGlobal [$ReadOption $Global $TypeofBool false];
    :local pReturn [$ReadOption $Return $TypeofBool true];
    # set start indent
    :local si "";
    :for i from=1 to=$cursor step=1 do={
        :set si ($si . $indent);
    }
    # set declaration
    :local declare "local";
    :if ($pGlobal) do={:set declare "global"}
    # init LSL
    :local LSL [$NewArray ];
    :local flagType true;
    # str
    :if ($flagType and [$IsStr $2]) do={
        :set flagType false;
        :set ($LSL->0) "$si:$declare $1 \"$2\";";
    }
    # array empty
    :if ($flagType and [$IsArray $2] and ([:len $2] = 0)) do={
        :set flagType false;
        :set ($LSL->0) "$si:$declare $1 ({});";
    }
    # array
    :if ($flagType and [$IsArrayN $2]) do={
        :set flagType false;
        :set ($LSL->0) "$si:$declare $1 {";
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
            :if (![$IsArrayN $queueNext]) do={
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
                        :for i from=0 to=$cursor step=1 do={
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
                        :local fT true;
                        :if ([:typeof $v] = $TypeofArray) do={
                            :set fT false;
                            :if ([:len $v] = 0) do={
                                :local lineStr "$ind$ks({})";
                                :set ($subLSL->[:len $subLSL]) $lineStr;
                            } else {
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
                            }
                        };
                        :if ([:typeof $v] = $TypeofStr) do={
                            :set fT false;
                            :local lineStr;
                            :local noquote "noquote:";
                            :if ([$StartsWith $v $noquote]) do={
                                :local vs [:pick $v [:len $noquote] [:len $v]];
                                :set lineStr "$ind$ks$vs;";
                            } else {
                                :set lineStr "$ind$ks\"$v\";";
                            }
                            :set ($subLSL->[:len $subLSL]) $lineStr;
                        }
                        # rest of type
                        :if ($fT) do={
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
    }
    # the rest type
    :if ($flagType) do={
        :set ($LSL->0) "$si:$declare $1 $2;";
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


# $SetGlobalVar
# set global variables
# TODO: let it still work after reboot
# args: <str>                       variable's name
# args: <var>                       variable's value, not nil
# opt kwargs: Timeout=<time>        timeout(sec)
:global SetGlobalVar do={
    # global declare
    :global IsStr;
    :global IsNil;
    :global IsNothing;
    :global IsStr;
    :global IsEmpty;
    :global Join;
    :global TypeofStr;
    :global TypeofTime;
    :global ReadOption;
    :global TypeRecovery;
    :global GetCurrentDatetime;
    :global ShiftDatetime;
    :global GetSDT;
    # check
    :if (![$IsStr $1]) do={
        :error "Global.Package.SetGlobalVar: \$1 should be str";
    };
    :local name $1;
    :if ([$IsNothing $2] or [$IsNil $2]) do={
        :error "Global.Package.SetGlobalVar: \$2 should be neither nothing nor nil";
    };
    # FIXME: :local value [$TypeRecovery $2];
    # [$TypeRecovery "0.1.0"] -> 0.0.0.1(ip)
    :local value $2;
    :local timeout [$ReadOption $Timeout $TypeofTime 0:0:0]
    :if ($timeout < 0:0:0) do={
        :error "Global.Package.SetGlobalVar: \$Timeout should greater than 00:00:00";
    };
    :local funcStr;
    :if ([:typeof $value] = $TypeofStr) do={
        :set funcStr ":global $name \"$value\";";
    } else {
        :set funcStr ":global $name $value;";
    };
    # parse exec
    :local func [:parse $funcStr];
    [$func ];
    # timeout check
    :if ($timeout > 0:0:0 and $timeout < 0:1:0) do={
        :error "Global.Package.SetGlobalVar: \$Timeout should longer than 1 minute";
    }
    # timeout
    :if ($timeout > 0:0:0) do={
        :local cdt [$GetCurrentDatetime ];
        :local tdt [$ShiftDatetime $cdt $timeout];
        :local sdt [$GetSDT $tdt];
        :local startTime ($sdt->"time");
        :local startDate ($sdt->"date");
        :local scheduleName "RSPM_SetGlobalVar_$name_Timeout";
        :local idList [/system scheduler find name=$scheduleName];
        :if ([$IsEmpty $idList]) do={
            :local eventStrList {
                "/system script environment remove $name;";
                "/system scheduler remove $scheduleName;";
            }
            :local eventStr [$Join ("\r\n") $eventStrList];
            /system scheduler add name=$scheduleName start-date=$startDate start-time=$startTime on-event=$eventStr;
        } else {
            :local sID ($idList->0);
            /system scheduler set numbers=$sID start-date=$startDate start-time=$startTime;
        }
    }
}


# $LoadGlobalVar
# load global variables from environment, raise error if value is nil or nothing. 
# args: <str>                       variable's name
# return: <var>                     value, return nil if not found
:global LoadGlobalVar do={
    # global declare
    :global Nil;
    :global IsStr;
    :global IsNil;
    :global IsEmpty;
    :global IsNothing;
    # check
    :if (![$IsStr $1]) do={
        :error "Global.Package.LoadGlobalVar: \$1 should be str";
    };
    :local varName $1;
    # load
    :local eID [/system script environment find name=$varName];
    :if ([$IsEmpty $eID]) do={
        :return $Nil;
    } else {
        :local funcStr ":global $varName;:return \$$varName;";
        :local func [:parse $funcStr];
        :local result [$func ];
        :if ([$IsNil $result] or [$IsNothing $result]) do={
            :error "Global.Package.LoadGlobalVar: load a nil or nothing value";
        };
        :return $result;
    }
}


# $UnsetGlobalVar
# unset a global variable
# args: <str>                       variable's name
:global UnsetGlobalVar do={
    # global declare
    :global IsStrN;
    :global IsEmpty;
    # check
    :if (![$IsStrN $1]) do={:error "Global.Package.UnsetGlobalVar: \$1 should be a string"};
    :local varName $1;
    # from environment
    /system script environment remove [/system script environment find name=$varName];
    # from scheduler
    :local scheduleName "RSPM_SetGlobalVar_$varName_Timeout";
    /system scheduler remove [/system scheduler find name=$scheduleName];
}


# package info
:local package {
    "metaInfo"=$metaInfo;
}
:return $package;
