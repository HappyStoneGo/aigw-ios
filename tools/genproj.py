#!/usr/bin/env python3
"""生成 Xcode 工程（pbxproj）。运行：python3 tools/genproj.py"""
import os, sys, hashlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = "AIGW"

def sid(s):
    return hashlib.md5(s.encode()).hexdigest()[:24].upper()

build_files, file_refs, groups_txt = [], [], []
src_ids, res_ids = [], []

def group_path(rel_dir):
    return rel_dir or ""

def add_file(rel_rel_to_group, abs_rel):
    name = os.path.basename(abs_rel)
    if name.endswith(".swift"):
        typ, phase = "sourcecode.swift", "sources"
    elif name.endswith(".xcassets"):
        typ, phase = "folder.assetcatalog", "resources"
    else:
        typ, phase = "text", None
    frid = sid("f:" + abs_rel)
    file_refs.append(
        '\t\t{f} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = {t}; path = "{p}"; sourceTree = "<group>"; }};'
        .format(f=frid, n=name, t=typ, p=rel_rel_to_group))
    if phase:
        bfid = sid("b:" + abs_rel)
        build_files.append(
            '\t\t{b} /* {n} in {ph} */ = {{isa = PBXBuildFile; fileRef = {f} /* {n} */; }};'
            .format(b=bfid, n=name, ph=phase, f=frid))
        (src_ids if phase == "sources" else res_ids).append((bfid, name))
    return frid

def walk(rel_dir):
    """返回组 id，递归建子组"""
    abs_dir = os.path.join(ROOT, rel_dir) if rel_dir else ROOT
    gid = sid("g:" + (rel_dir or "<main>"))
    children = []
    for name in sorted(os.listdir(abs_dir)):
        full = os.path.join(abs_dir, name)
        abs_rel = os.path.join(rel_dir, name) if rel_dir else name
        if os.path.isdir(full):
            if name.endswith(".xcassets"):
                children.append(add_file(name, abs_rel))
            else:
                children.append(walk(abs_rel))
        elif name == "Info.plist" or name.startswith("."):
            continue
        else:
            children.append(add_file(name, abs_rel))
    ch = "\n".join('\t\t\t\t{c} /* x */,'.format(c=c) for c in children)
    path_line = '\t\t\tpath = "{p}";'.format(p=os.path.basename(rel_dir)) if os.path.dirname(rel_dir) else ''
    if not path_line:
        path_line = '\t\t\tname = "{n}";'.format(n=os.path.basename(rel_dir))
    if not rel_dir:
        path_line = ''
    groups_txt.append(
        '\t\t{g} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{ch}\n\t\t\t);\n{pl}\n\t\t\tsourceTree = "<group>";\n\t\t}};'
        .format(g=gid, ch=ch, pl=path_line))
    return gid

main_src_gid = walk(SRC)

products_gid = sid("g:Products")
product_ref = sid("f:product")
file_refs.append(
    '\t\t{p} /* AIGW.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AIGW.app; sourceTree = BUILT_PRODUCTS_DIR; }};'.format(p=product_ref))
groups_txt.append(
    '\t\t{g} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{p} /* AIGW.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t}};'.format(g=products_gid, p=product_ref))

root_gid = sid("g:<root>")
groups_txt.append(
    '\t\t{g} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{s} /* AIGW */,\n\t\t\t\t{p} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t}};'.format(g=root_gid, s=main_src_gid, p=products_gid))

proj_id   = sid("project")
target_id = sid("target")
ph_src    = sid("ph:sources")
ph_fw     = sid("ph:frameworks")
ph_res    = sid("ph:resources")
cl_proj   = sid("cl:proj")
cl_target = sid("cl:target")

SHARED = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;"""

TARGET = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGNING_REQUIRED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = AIGW/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.aigw.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";"""

def list_block(items):
    return "\n".join('\t\t\t\t{b} /* {n} */,'.format(b=b, n=n) for b, n in items)

pbx = """// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{bf}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{fr}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{fw} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{groups}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{t} /* AIGW */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {clt};
\t\t\tbuildPhases = (
\t\t\t\t{src} /* Sources */,
\t\t\t\t{fw} /* Frameworks */,
\t\t\t\t{res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = AIGW;
\t\t\tproductName = AIGW;
\t\t\tproductReference = {prod} /* AIGW.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{p} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t}};
\t\t\tbuildConfigurationList = {clp};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = zh_CN;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\tzh_CN,
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {root};
\t\t\tproductRefGroup = {pg} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{t} /* AIGW */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{rl}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{src} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sl}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{c1} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{shared}
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{c2} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{shared}
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{c3} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{target}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{c4} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{target}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{clp} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{c1} /* Debug */,
\t\t\t\t{c2} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{clt} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{c3} /* Debug */,
\t\t\t\t{c4} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {p} /* Project object */;
}}
""".format(bf="\n".join(build_files), fr="\n".join(file_refs),
           groups="\n\n".join(groups_txt),
           fw=ph_fw, t=target_id, clt=cl_target, src=ph_src, res=ph_res,
           prod=product_ref, p=proj_id, clp=cl_proj, root=root_gid, pg=products_gid,
           rl=list_block(res_ids), sl=list_block(src_ids),
           c1=sid("c:proj:debug"), c2=sid("c:proj:release"),
           c3=sid("c:tag:debug"), c4=sid("c:tag:release"),
           shared=SHARED, target=TARGET)

out_dir = os.path.join(ROOT, "AIGW.xcodeproj")
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "project.pbxproj"), "w") as f:
    f.write(pbx)

# 验证：所有被引用的 24 位 id 都在 objects 里定义
import re
defined = set(re.findall(r'^\t\t([0-9A-F]{24}) ', pbx, re.M))
refs = set(re.findall(r'\b([0-9A-F]{24})\b', pbx))
missing = refs - defined
print("sources:", len(src_ids), "resources:", len(res_ids))
print("missing ids:", missing if missing else "none")
