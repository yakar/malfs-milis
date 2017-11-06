#!/bin/sh
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
# Copyright 1997-2016 Oracle and/or its affiliates. All rights reserved.
#
# Oracle and Java are registered trademarks of Oracle and/or its affiliates.
# Other names may be trademarks of their respective owners.
#
# The contents of this file are subject to the terms of either the GNU
# General Public License Version 2 only ("GPL") or the Common
# Development and Distribution License("CDDL") (collectively, the
# "License"). You may not use this file except in compliance with the
# License. You can obtain a copy of the License at
# http://www.netbeans.org/cddl-gplv2.html
# or nbbuild/licenses/CDDL-GPL-2-CP. See the License for the
# specific language governing permissions and limitations under the
# License.  When distributing the software, include this License Header
# Notice in each file and include the License file at
# nbbuild/licenses/CDDL-GPL-2-CP.  Oracle designates this
# particular file as subject to the "Classpath" exception as provided
# by Oracle in the GPL Version 2 section of the License file that
# accompanied this code. If applicable, add the following below the
# License Header, with the fields enclosed by brackets [] replaced by
# your own identifying information:
# "Portions Copyrighted [year] [name of copyright owner]"
#
# Contributor(s):
#
# The Original Software is NetBeans. The Initial Developer of the Original
# Software is Sun Microsystems, Inc. Portions Copyright 1997-2007 Sun
# Microsystems, Inc. All Rights Reserved.
#
# If you wish your version of this file to be governed by only the CDDL
# or only the GPL Version 2, indicate your decision by adding
# "[Contributor] elects to include this software in this distribution
# under the [CDDL or GPL Version 2] license." If you do not indicate a
# single choice of license, a recipient has the option to distribute
# your version of this file under either the CDDL, the GPL Version 2 or
# to extend the choice of license to its licensees as provided above.
# However, if you add GPL Version 2 code and therefore, elected the GPL
# Version 2 license, then the option applies only if the new code is
# made subject to such option by the copyright holder.

#
# resolve symlinks
#

PRG=$0

while [ -h "$PRG" ]; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '^.*-> \(.*\)$' 2>/dev/null`
    if expr "$link" : '^/' 2> /dev/null >/dev/null; then
	PRG="$link"
    else
	PRG="`dirname "$PRG"`/$link"
    fi
done

progdir=`dirname "$PRG"`
old=`pwd`
cd "$progdir"/..
basedir=`pwd`
cd "$old"

case "`uname`" in
    Darwin*)
        # set default userdir and cachedir on Mac OS X
        DEFAULT_USERDIR_ROOT="${HOME}/Library/Application Support/NetBeans"
        DEFAULT_CACHEDIR_ROOT=${HOME}/Library/Caches/NetBeans
        ;;
    *) 
        # set default userdir and cachedir on unix systems
        DEFAULT_USERDIR_ROOT=${HOME}/.netbeans
        DEFAULT_CACHEDIR_ROOT=${HOME}/.cache/netbeans
        ;;
esac


if [ -f "$basedir"/etc/netbeans.conf ] ; then
    . "$basedir"/etc/netbeans.conf
fi

# following should be done just in RPM or Solaris Launcher
# if [ -f /etc/netbeans.conf ] ; then
#     . /etc/netbeans.conf
# fi

export DEFAULT_USERDIR_ROOT

# #68373: look for userdir, but do not modify "$@"
userdir="${netbeans_default_userdir}"
cachedir="${netbeans_default_cachedir}"

founduserdir=""
for opt in "$@"; do
    if [ "${founduserdir}" = "yes" ]; then
        userdir="$opt"
        break
    elif [ "$opt" = "--userdir" ]; then
        founduserdir="yes"
    fi
done
foundcachedir=""
for opt in "$@"; do
    if [ "${foundcachedir}" = "yes" ]; then
        cachedir="$opt"
        break
    elif [ "$opt" = "--cachedir" ]; then
        foundcachedir="yes"
    fi
done

if [ -f "${userdir}"/etc/netbeans.conf ] ; then
    . "${userdir}"/etc/netbeans.conf
fi


if [ ! -f "$basedir"/etc/netbeans.clusters ]; then
    echo Cannot read cluster file: "$basedir"/etc/netbeans.clusters 1>&2
    exit 1
fi

readClusters() {
    grep -v "^#" "$basedir"/etc/netbeans.clusters | grep -v "^$" | grep -v platform | while read X; do
        if expr "$X" : "/.*" >/dev/null; then
            echo "$X"
        else
            echo "$basedir/$X"
        fi
    done
}

absolutize_paths() {
    while read path; do
        if [ -d "$path" ]; then
            (cd "$path" 2>/dev/null && pwd)
        else
            echo "$path"
        fi
    done
}

netbeans_clusters=`readClusters | absolutize_paths | tr '\012' ':'`

if [ ! -z "$netbeans_extraclusters" ] ; then
    netbeans_clusters="$netbeans_clusters:$netbeans_extraclusters"
fi

heap_size () {
    mem=640
    case "`uname`" in
        Linux*)
        mem=`cat /proc/meminfo | grep MemTotal | tr -d [:space:][:alpha:]:`
        mem=`expr $mem / 1024`
        ;;
    SunOS*)
        mem=`/usr/sbin/prtconf | grep Memory | /usr/bin/tr -dc '[0-9]'`
        ;;
    Darwin*)
        mem=`/usr/sbin/sysctl hw.memsize | tr -d [:alpha:][:space:].:`
        mem=`expr $mem / 1048576`
        ;;
        *) 
        ;;
    esac
    if [ -z "$mem" ] ; then
        mem=640
    fi
    mem=`expr $mem / 5`
    if [ $mem -gt 1024 ] ; then
        mem=1024
    elif [ $mem -lt 96 ] ; then
        mem=96
    fi
    max_heap_size=$mem
    return 0
}


if grep -v -- "-J-Xmx" >/dev/null <<EOF ; then
${netbeans_default_options}
EOF
        heap_size
	netbeans_default_options="-J-Xmx${max_heap_size}m ${netbeans_default_options}"
fi

launchNbexec() {
    nbexec="/usr/share/netbeans/platform/lib/nbexec"
    sh="/bin/bash"
    #exec $sh "$nbexec"
    source /etc/netbeans.conf
    exec $sh "$nbexec" $netbeans_default_options --userdir "${userdir}" --cachedir "${cachedir}" 
    #"$@"
    
}

# in case of macosx, the apple.laf.useScreenMenuBar property should be ideally in the Info.plist file
# but it doesn't get propagated into the executed java VM. 
case "`uname`" in
    Darwin*)
        eval launchNbexec \
            --jdkhome '"$netbeans_jdkhome"' \
            -J-Xdock:name=NetBeans \
            '"-J-Xdock:icon=$basedir/nb/netbeans.icns"' \
            --branding nb \
            --clusters '"$netbeans_clusters"' \
            -J-Dnetbeans.importclass=org.netbeans.upgrade.AutoUpgrade \
            -J-Dnetbeans.accept_license_class=org.netbeans.license.AcceptLicense \
            ${netbeans_default_options} \
            '"$@"'
        ;;
    *)
        eval launchNbexec \
            --jdkhome '"$netbeans_jdkhome"' \
            --branding nb \
            --clusters '"$netbeans_clusters"' \
            -J-Dnetbeans.importclass=org.netbeans.upgrade.AutoUpgrade \
            -J-Dnetbeans.accept_license_class=org.netbeans.license.AcceptLicense \
            ${netbeans_default_options} \
            '"$@"'
        ;;
esac
