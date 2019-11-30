#!/usr/bin/awk -f

#-
# Copyright (c) 2006 Max Laier.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS `AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD: src/sys/tools/fw_stub.awk,v 1.6.10.2 2009/11/02 09:47:15 fjoe Exp $

#
# Script to generate module .c file from a list of firmware images
#

function usage ()
{
	print "usage: fw_stub <firmware:name[:version[:parent]]>* [-l name] [-c outfile] -m modname";
	exit 1;
}

#   These are just for convenience ...
function printc(s)
{
	if (opt_c)
		print s > ctmpfilename;
	else
		print s > "/dev/stdout";
}

BEGIN {

#
#   Process the command line.
#

num_files = 0;

for (i = 1; i < ARGC; i++) {
	if (ARGV[i] ~ /^-/) {
		#
		#   awk doesn't have getopt(), so we have to do it ourselves.
		#   This is a bit clumsy, but it works.
		#
		for (j = 2; j <= length(ARGV[i]); j++) {
			o = substr(ARGV[i], j, 1);
			if (o == "c") {
				if (length(ARGV[i]) > j) {
					opt_c = substr(ARGV[i], j + 1);
					break;
				}
				else {
					if (++i < ARGC) {
						opt_c = ARGV[i];
						break;
					} else {
						usage();
					}
				}
			} else if (o == "m") {
				if (length(ARGV[i]) > j) {
					opt_m = substr(ARGV[i], j + 1);
					break;
				}
				else {
					if (++i < ARGC) {
						opt_m = ARGV[i];
						break;
					} else {
						usage();
					}
				}
			} else if (o == "l") {
				if (length(ARGV[i]) > j) {
					opt_l = substr(ARGV[i], j + 1);
					break;
				}
				else {
					if (++i < ARGC) {
						opt_l = ARGV[i];
						break;
					} else {
						usage();
					}
				}
			} else
				usage();
		}
	} else {
		split(ARGV[i], curr, ":");
		filenames[num_files] = curr[1];
		if (length(curr[2]) > 0)
			shortnames[num_files] = curr[2];
		else
			shortnames[num_files] = curr[1];
		if (length(curr[3]) > 0)
			versions[num_files] = int(curr[3]);
		else
			versions[num_files] = 0;
		num_files++;
	}
}

if (!num_files || !opt_m)
	usage();

cfilename = opt_c;
ctmpfilename = cfilename ".tmp";
modname = opt_m;
gsub(/[-\.]/, "_", modname);

printc("#include <sys/param.h>\n"\
    "#include <sys/errno.h>\n"\
    "#include <sys/kernel.h>\n"\
    "#include <sys/module.h>\n"\
    "#include <sys/linker.h>\n"\
    "#include <sys/firmware.h>\n"\
    "#include <sys/systm.h>\n");

if (opt_l) {
	printc("static long " opt_l "_license_ack = 0;");
}

for (file_i = 0; file_i < num_files; file_i++) {
	symb = filenames[file_i];
	# '-', '.' and '/' are converted to '_' by ld/objcopy
	gsub(/-|\.|\//, "_", symb);
	printc("extern char _binary_" symb "_start[], _binary_" symb "_end[];");
}

printc("");
printc("static int\n"\
	modname "_fw_modevent(module_t mod, int type, void *unused)\n"\
	"{\n"\
	"	const struct firmware *fp;");

if (num_files > 1)
	printc("\tconst struct firmware *parent;");

printc("	int error;\n"\
	"\n"\
	"	switch (type) {\n"\
	"	case MOD_LOAD:\n");

if (opt_l) {
	printc("");
	printc("\tTUNABLE_LONG_FETCH(\"legal." opt_l ".license_ack\", &" opt_l "_license_ack);\n"\
	    "\tif (!" opt_l "_license_ack) {\n"\
	    "\t	kprintf(\"" opt_m ": You need to read the LICENSE file in /usr/share/doc/legal/" opt_l "/.\\n\");\n"\
	    "\t	kprintf(\"" opt_m ": If you agree with the license, set legal." opt_l ".license_ack=1 in /boot/loader.conf.\\n\");\n"\
	    "\t	return(EPERM);\n"\
	    "\t}\n");
}

for (file_i = 0; file_i < num_files; file_i++) {
	short = shortnames[file_i];
	symb = filenames[file_i];
	version = versions[file_i];
	# '-', '.' and '/' are converted to '_' by ld/objcopy
	gsub(/-|\.|\//, "_", symb);

	reg = "\t\tfp = ";
	reg = reg "firmware_register(\"" short "\", _binary_" symb "_start , ";
	reg = reg "(size_t)(_binary_" symb "_end - _binary_" symb "_start), ";
	reg = reg version ", ";

	if (file_i == 0)
		reg = reg "NULL);";
	else
		reg = reg "parent);";

	printc(reg);

	printc("\t\tif (fp == NULL)");
	printc("\t\t\tgoto fail_" file_i ";");
	if (file_i == 0 && num_files > 1)
		printc("\t\tparent = fp;");
}

printc("\t\treturn (0);");

for (file_i = num_files - 1; file_i > 0; file_i--) {
	printc("fail_" file_i ":")
	printc("\t\t(void)firmware_unregister(\"" shortnames[file_i - 1] "\");");
}

printc("\tfail_0:");
printc("\t\treturn (ENXIO);");

printc("\tcase MOD_UNLOAD:");

for (file_i = 1; file_i < num_files; file_i++) {
	printc("\t\terror = firmware_unregister(\"" shortnames[file_i] "\");");
	printc("\t\tif (error)");
	printc("\t\t\treturn (error);");
}

printc("\t\terror = firmware_unregister(\"" shortnames[0] "\");");

printc("\t\treturn (error);\n"\
    "	}\n"\
    "	return (EINVAL);\n"\
    "}\n"\
    "\n"\
    "static moduledata_t " modname "_fw_mod = {\n"\
    "        \"" modname "_fw\",\n"\
    "        " modname "_fw_modevent,\n"\
    "        0\n"\
    "};\n"\
    "DECLARE_MODULE(" modname "_fw, " modname "_fw_mod, SI_SUB_DRIVERS, SI_ORDER_FIRST);\n"\
    "MODULE_VERSION(" modname "_fw, 1);\n"\
    "MODULE_DEPEND(" modname "_fw, firmware, 1, 1, 1);\n");

if (opt_c)
	if ((rc = system("mv -f " ctmpfilename " " cfilename))) {
		print "'mv -f " ctmpfilename " " cfilename "' failed: " rc \
		    > "/dev/stderr";
		exit 1;
	}

exit 0;

}
