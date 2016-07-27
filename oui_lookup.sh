#!/bin/sh

#Copyright (c) 2016, Aaron McCall
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:
#
#* Redistributions of source code must retain the above copyright notice, this
#  list of conditions and the following disclaimer.
#
#* Redistributions in binary form must reproduce the above copyright notice,
#  this list of conditions and the following disclaimer in the documentation
#  and/or other materials provided with the distribution.
#
#* Neither the name of oui_lookup nor the names of its
#  contributors may be used to endorse or promote products derived from
#  this software without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# See help function or run mac_lookup.sh -h for info
set -e
curl_url=http://linuxnet.ca/ieee/oui/nmap-mac-prefixes
oui_dl="/tmp/oui.txt"

# FUNCTION scrub_mac(){{{1
scrub_mac(){
echo $1 | sed 's/://g;s/-//g;s/\.//g' |  grep -Eo "[0-9A-Fa-f]{12}" | cut -c 1-6 | tr "[:lower:]" "[:upper:]"
}
# FUNCTION verify_oui_file(){{{1
verify_oui_file(){
    if [ ! -f "$1" ]; then
        printf "OUI file not found. Exiting...\n"
        exit 1
    fi
}
# FUNCTION help_output(){{{1
help_output() { 
printf "Usage: mac_lookup.sh [option] MAC\n\n"
printf "\- MAC can be a single string or a file containing a list of MAC addresses\n"
printf "\- Only first instance of a MAC is matched per line when searching file\n\n"
printf "\-b, text to include before OUI output (use quotes to include white space)\n"
printf "\-a, text to include after OUI output (use quotes to include white space)\n"
printf "\-h, this output\n"
printf "\-w, Download OUI list to /tmp from http://linuxnet.ca/ieee/oui/nmap-mac-prefixes for search *Requires curl\n"
printf "\-s, source local OUI list\n\n"
printf "Examples:\n\n"
printf "1: list of addresses, source local OUI file, include comma before OUI:\n"
printf "mac_lookup.sh -b , -s /foo/bar/oui_list.txt /foo/bar/mac_list.csv\nOutput:\n"
printf "1,E043:db31:4121,Shenzhen ViewAt\n2,2c30-3324-3555,Netgear\n3,9C8e.993e.444e,HP\n\n"
printf "2: Single addresses, remote searce:\n"
printf "mac_lookup.sh E043:db31:4121\nOutput:\n"
printf "Shenzhen ViewAt\n"
}

# Function start_search(){{{1
start_search(){
    # Check if argument is single MAC or points to file
    if [ ! -f "$mac_add" ]; then
        if [ ! $web_source_arg ] && [ ! $local_source_arg ]; then
            output=$(curl --use-ascii --silent $curl_url | grep $(scrub_mac "$mac_add") | sed 's/^.\{7\}//')
            printf "%s%s%s\n" "$before_arg" "$output" "$after_arg"
        elif [ $web_source_arg ]; then
            curl --silent $curl_url > $oui_dl
            output=$(cat $oui_dl | grep $(scrub_mac "$mac_add") | sed 's/^.\{7\}//')
            printf "%s%s%s\n" "$before_arg" "$output" "$after_arg"
        elif [ $local_source_arg ]; then
            verify_oui_file $local_source_arg
            output=$(cat $local_source_arg | grep $(scrub_mac "$mac_add") | sed 's/^.\{7\}//')
            printf "%s%s%s\n" "$before_arg" "$output" "$after_arg"
        fi
    # Looks to be a file, loop through search
    else 
        if [ ! $web_source_arg ] && [ ! $local_source_arg ]; then
            printf "Choose source, local or web. Remote search will be painfully slow for list of MACs"
            exit 1
        elif [ $web_source_arg ]; then
            curl --silent $curl_url > $oui_dl
            while read p
            do
                output=$(cat $oui_dl | grep $(scrub_mac "$p") | sed 's/^.\{7\}//')
                printf "%s%s%s%s\n" "$p" "$before_arg" "$output" "$after_arg"
            done < $mac_add
        elif [ $local_source_arg ]; then
            verify_oui_file $local_source_arg
            while read p
            do
                output=$(cat $local_source_arg | grep $(scrub_mac "$p") | sed 's/^.\{7\}//')
                printf "%s%s%s%s\n" "$p" "$before_arg" "$output" "$after_arg"
            done < $mac_add
        fi
    fi
}
# Arguments{{{1
while getopts ":s:a:b:hw" opt; do
    case $opt in
        a)
            after_arg=$OPTARG
            shift
            shift
            ;;
        b)
            before_arg=$OPTARG
            shift
            shift
            ;;
        h)
            help_arg=true
            shift
            ;;
        w)
            web_source_arg=true
            shift
            ;;
        s)
            local_source_arg=$OPTARG
            shift
            shift
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
# Verify required argument(s) and start search{{{1
if [ $help_arg ]; then
    help_output
    exit 0
fi

if [ $local_source_arg ] && [ $web_source_arg ]; then
    printf "Both -w and -s flags set. See help...\n\n"
    help_output
    exit 1
fi
if [ -z $1 ]; then
    printf "Require MAC address or file containing MAC addresses to proceed\n\n"
    exit 1
fi
mac_add=$1
start_search
