#!/bin/bash
#
# GNU General Public License v3.0
#
# Name   : trsync.sh - a bash script for carrying out rsync data
#          transfer tests using selected test datasets via remote
#          shell, rsync daemon, or the parsyncfp perl wrapper of
#          rsync.
#
# Author : Chin Fang <fangchin@zettar.com>
#
# Purpose: Make it explicit what can be achieved using rsync in an
#          environment where fast network (>= 10Gbps, LAN, Metro, or
#          WAN) and storage (>=10Gbps) are available.
#
# Remarks: 0. The script uses only hyperscale data sets in three different
#             size ranges. Hyperscale data set is a dataset that consists of
#             >= 1M files, or overall size >= 1TB, or both.
#             0.0 LOSF
#             0.1 Medium size files
#             0.2 Large sized files
#          1. Owing to the obvious slow transfer rates attainable with rsync,
#             the "median" datasets in each range is selected as the default
#             to save time.
#             1.0 1048576x{16,32,64,128,256,512}KiB can be used.
#                 1048576x256KiB (default)
#             1.1 4096x256MiB
#             1.2 4x256GiB
#
# Usage : As root on the two nodes, one source and one target, login
#         the source node as root, assuming between the two nodes, the
#         root can use ssh key based login, then on the command line:
#         # trsync.sh -h to see the available options and examples.
#
#         Running under root is necessary as the script drops the page
#         cache to make the results fair. Dropping page cache is a
#         priviledged operation.
#
#         It is recommended to install the script in
#         source_node:/usr/local/sbin
#
# Notes:
#
# 0. The test datasets have the following overall sizes:
#    o  1048576x16KiB:  16GiB =  137.4387Gbits
#       1048576x32KiB:  32GiB =  274.8775Gbits
#       1048576x64KiB:  64GiB =  549.7549Gbits
#      1048576x128KiB: 128GiB = 1099.5098Gbits
#      1048576x256KiB: 256GiB = 2199.0195Gbits
#      1048576x256KiB: 512GiB = 4398.0390Gbits
#
#      Owing to the importance of LOSF for a few industries, such as
#      Life Sciences, EDA, and AI/ML/DL, these datasets are tested for
#      this range.
#
#    o 4096x256MiB   : 1TiB = 8796.07808 Gbits
#    o 4x256GiB      : 1TiB = 8796.07808 Gbits
# 1. The default environment is a Zettar testbed, which is described
#    more below.  But the tester script is designed to be fully usable
#    elsewhere.
# 2. The Zettar testbed is intentionally kept in a modest state of tune.
#    The key reason is that majority of Zettar enterprise customers are
#    not skillful in this area, so we keep our own environment "modest".
# 3. With the Zettar testbed environment, the storage of the two test
#    nodes is formed using 8xIntel DC P3700 NVMe 1.6TB SSDs, imported
#    into the two test nodes via NVMeoF (IB FDR 56Gbps), then
#    aggregated into a Linux software RAID 0. Each test node has
#    2xIntel(R) Xeon(R) Gold 6126 CPU @ 2.60GHz and 256GB RAM. The
#    connection between the two test nodes is 2x25Gbps Ethernet.
# 4. This script has been checked by shellcheck without any warnings
#    and errors.

# A few global variables. Contrary to a myth popular among newbie
# programmers, if judiciously employed, global variables simplify
# programming :D
#
aindex=4  # for the 1048576x256KiB LOSF test dataset
ssh_port=
address=192.168.15.20
daemon=
src_data_dir=/var/local/zettar/zx/src_data # the source node's data dir
dst_data_dir=/var/local/zettar/zx/dst_data # the target node's data dir
run_wrapper=
ncore=$(nproc)
num_inst=$(echo "scale=1; sqrt($ncore)"|bc)
num_inst=$(echo "$num_inst"|awk '{print int($1)}')
iface=
verbose=
dry_run=

declare -a datasets=('1048576x16KiB'
		     '1048576x32KiB'
		     '1048576x64KiB'
		     '1048576x128KiB'
		     '1048576x256KiB'
		     '1048576x512KiB'
		     '4096x256MiB'
		     '4x256GiB')

help()
{
    local help_str=''
    read -r -d '' help_str <<'EOF'
This script is for carrying out rsync data transfer tests using
selected test datasets via remote shell, rsync daemon, or the
parsyncfp perl wrapper of rsync.  To learn it, use its dry-run option
-n.

Its purpose is to make it explicit what can be achieved using rsync in
in an environment where fast network (>= 10Gbps, LAN, Metro, or WAN)
and storage (>=10Gbps) are available.

Owing to the importance of LOSF to some industries, e.g. Life
Sciences, EDA, and AI/ML/DL, three datasets can be used for the LOSF
range, using the -a option below, a=0 for 16KiB, a=1 for 32KiB, and
a=2 for 64KiB, a=3 for 128KiB, a=4 for 256KiB. Default 256KiB.

Command line options:
    -h show this help
    -r the range to test, one of s: LOSF, m: medium, l: large.  If not 
       specified, a test covering all three ranges is carried out
    -a array index for the test datset array
    -p the port for ssh connections
    -i target IPv4 address
    -S the path of the source directory with the desired hyperscale datasets
    -D the path of the destination directory
    -d connect to the target via rsync daemon (must be set up & named backup!)
    -P run the parsyncfp perl wrapper
    -N number of rsync instances (default sqrt(#CPUs)). No effect without -P
    -I the interface to use. No effect without -P
    -v executed commands are displayed. Do not use for dry-runs
    -n displays the command used without running (dry run). For verification

The usage (on the source node): 
# trsync.sh [-h][-r range][-p ssh port][-i ipv4_address][-S src_data_dir]\
  [-D dst_data_dir][-d][-P][-N num][-I iface][-v][-n]

Examples: 0. # trsync.sh -r s -i 192.168.15.20 \
               -S /var/local/zettar/zx/src_data \
               -D /var/local/zettar/zx/dst_data
          1. # trsync.sh -r s -i 192.168.15.20 \
               -S /var/local/zettar/zx/src_data \
               -D /var/local/zettar/zx/dst_data -d
          2. # trsync.sh -r s -i 192.168.15.20 \
               -S /var/local/zettar/zx/src_data \
               -D /var/local/zettar/zx/dst_data -P -I enp175s0f0
          3. # trsync.sh -r s -i 192.168.15.20 \
               -S /var/local/zettar/zx/src_data \
               -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -p 22

In the above examples 
0   shows to carry out a run over the LOSF test case only
1   shows to carry out a run over the LOSF test with rsync daemon on 
    192.168.15.20
2   shows to how to use the parsyncfp via the standard ssh port (22)
3   shows to how to use the parsyncfp via possibly a custom port
EOF
    echo "$help_str"
    exit 0
}

rsyncd_or_rsync()
{
    local ds
    ds=$1
    local cmd
    cmd='rsync -a '
    cmd+="$src_data_dir"/
    cmd+="$ds "
    if [[ "$daemon" ]]; then
	cmd+="$address"::backup
	if [[ "$dry_run" ]]; then
	    echo "$cmd"
	else
	    [[ "$verbose" ]] && echo "$cmd"
	    $cmd
	fi
    else
	cmd+="$address":"$dst_data_dir"
	if [[ "$dry_run" ]]; then
	   echo "$cmd"
	else
	    [[ "$verbose" ]] && echo "$cmd"
	    $cmd
	fi
    fi    
}

run_parsyncfp()
{
    local interface
    interface=$iface
    local ds
    ds=$1
    local cmd
    cmd="parsyncfp --NP $num_inst --startdir=$src_data_dir $ds "
    cmd+="--interface=$interface "
    cmd+="--nowait $address:$dst_data_dir"
    if [[ "$dry_run" ]]; then
	echo "$cmd"
    else
	[[ "$verbose" ]] && echo "$cmd"
	$cmd > /dev/null 2>&1
    fi
}

clean_up()
{
    local ds
    ds=$1
    rsync -a --delete "$src_data_dir"/temp/ "$address":"$dst_data_dir"/"$ds"/
}

losf_test()
{
    # LOSF
    if [[ -z "$dry_run" ]]; then
       local begin_test
       begin_test=$(date +"%s")
       # Clean out the page cache to ensure fairness
       echo "Clean up the page cache..."
       sync; echo 3 > /proc/sys/vm/drop_caches
       echo "Page cache cleaned."
    fi
    local i
    i="$aindex"
    local ds
    ds="${datasets[$i]}"
    if [[ -z "$dry_run" ]]; then   
	echo "Testing with $ds..."
	echo "Doing a preventive cleaning first..."
	clean_up  "$ds"
	echo "Preventive cleaning done."
    fi
    if [[ "$run_wrapper" ]]; then
	run_parsyncfp "$ds"
    else
	rsyncd_or_rsync "$ds"
    fi
    if [[ -z "$dry_run" ]]; then   
       local end_test
       end_test=$(date +"%s")
       local test_time
       test_time=$((end_test-begin_test))
       local test_speed
       local factor
       case "$i" in
	   0) factor=137.4387
	      ;;
	   1) factor=274.8875
	      ;;
	   2) factor=549.7549
	      ;;
	   3) factor=1099.5098
	      ;;
	   4) factor=2199.0195
	      ;;
	   5) factor=4398.0390
	      ;;	    
	   *) echo "Error: impossible index!"
	      exit 2
	      ;;
       esac
       test_speed=$(echo "scale=2; $factor / $test_time" | bc -l)
       echo "LOSF speed: $test_speed Gbps"
       echo "Cleaning, please wait..."
       # Clean it out to prepare for the next run
       clean_up  "$ds"
       echo "Cleaning done."
    fi
}

medium_file_test()
{
    # Medium
    if [[ -z "$dry_run" ]]; then
	local begin_test
	begin_test=$(date +"%s")    
	# Clean out the page cache to ensure fairness
	echo "Clean up the page cache..."    
	sync; echo 3 > /proc/sys/vm/drop_caches
	echo "Page cache cleaned."
    fi
    local i
    i="$aindex"
    local ds
    ds="${datasets[$i]}"
    if [[ -z "$dry_run" ]]; then    
	echo "Testing with $ds..."    
	echo "Doing a preventive cleaning first..."
	clean_up "$ds"
	echo "Preventive cleaning done."
    fi
    if [[ "$run_wrapper" ]]; then
	run_parsyncfp "$ds"   # '4096x256MiB'
    else
	rsyncd_or_rsync "$ds" # '4096x256MiB'
    fi
    if ! [[ "$dry_run" ]]; then
	local end_test
	end_test=$(date +"%s")
	test_time=$((end_test-begin_test))
	local test_speed
	test_speed=$(echo "scale=2; 8796.07808 / $test_time" | bc -l)
	echo "Medium speed: $test_speed Gbps" 
	echo "Cleaning, please wait..."    
	# Clean it out to prepare for the next run
	clean_up  "$ds"
	echo "Cleaning done."
    fi
}

large_file_test()
{
    # Large
    if [[ -z "$dry_run" ]]; then    
	local begin_test
	begin_test=$(date +"%s")
	# Clean out the page cache to ensure fairness
	echo "Clean up the page cache..."       
	sync; echo 3 > /proc/sys/vm/drop_caches
	echo "Page cache cleaned."
    fi
    local i
    i="$aindex"
    local ds
    ds="${datasets[$i]}"
    if [[ -z "$dry_run" ]]; then   
	echo "Testing with $ds..."        
	echo "Doing a preventive cleaning first..."        
	clean_up "$ds"
	echo "Preventive cleaning done."
    fi
    if [[ "$run_wrapper" ]]; then
	run_parsyncfp "$ds"   # '4x256GiB'
    else
	rsyncd_or_rsync "$ds" # '4x256GiB'
    fi
    if ! [[ "$dry_run" ]]; then
	local end_test
	end_test=$(date +"%s")
	test_time=$((end_test-begin_test))
	local test_speed
	test_speed=$(echo "scale=2; 8796.07808 / $test_time" | bc -l)
	echo "Large speed: $test_speed Gbps"
	echo "Cleaning, please wait..."        
	# Clean it out to prepare for the next run
	clean_up "$ds"
	echo "Cleaning done."
    fi
}

verify_range()
{
    local range_to_test
    range_to_test=$1
    local msg
    
    if [[ "$range_to_test" != [sml] ]]; then
        msg="Only s:LOSF, m:medium files, l:large files "
        msg+="allowed. Abort!"
        echo "$msg"
        exit 1
    fi    
}

verify_ssh_port()
{
    # Note, ssh_port is a global variable :)
    local msg
    
    if ! [[ "$ssh_port" =~ ^[1-9][0-9]*$ ]]; then
        msg="ssh_port must be a positive integer. Abort!"
        echo "$msg"
        exit 1
    fi     
}

ensure_datasets_exist()
{
    local full_ds_path
    local the_temp
    for ds in "${datasets[@]}"
    do
	full_ds_path="$src_data_dir"/"$ds"
	if [[ ! -d "$full_ds_path" ]]; then
            echo "Error: $full_ds_path doesn't exist! Generate it! Abort!"
            exit 1
	fi
	the_temp="$src_data_dir"/temp
	if [[ ! -d "$the_temp" ]]; then
	    echo "Error: without $src_data_dir/temp, no cleanup!"
	fi
    done
}

verify_num_inst()
{
    # Note, num_inst is a global variable :)
    local msg
    
    if ! [[ "$num_inst" =~ ^[1-9][0-9]*$ ]]; then
        msg="num_inst must be specified in a positive integer. Abort!"
        echo "$msg"
        exit 1
    fi
}

verify_iface()
{
    # Note, iface is a global variable :)
    local msg
    if /sbin/ethtool "$iface" | grep -q "Link detected: yes"; then
	:
    else
	echo "$iface not online. Abort!"
	exit 1
    fi   
}

# main()
{
    begin_test=$(date +"%s")
    while getopts ":hr:a:p:i:S:D:dPN:I:vn" opt; do
        case $opt in
            h)  help
                ;;
            r)  range_to_test=$OPTARG
                verify_range "$range_to_test"
                ;;
	    a)  aindex=$OPTARG
		if ! [[ "$aindex" =~ ^[0-7]$ ]]; then
		    echo "Error: the index must be in 0..7"
		    exit 1
		fi
		if [[ "$range_to_test" == 's' ]] &&
		       ! [[ "$aindex" =~ ^[0-5]$ ]]; then
		    echo "Error: index $aindex doesn't fit the LOSF range"
		    exit 1
		fi
		;;
	    p)  ssh_port=$OPTARG
		verify_ssh_port
		;;
            i)  address=$OPTARG
		if ! [[ "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    echo "Error: the given target address is invalid"
                    exit 1
		fi            
		;;
	    S) src_data_dir=$OPTARG
	       if ! [[ -d "$src_data_dir" ]]; then
		   echo "Error: the source data directory doesn't exist!"
		   exit 1
	       fi
	       ;;
	    D) dst_data_dir=$OPTARG # this is on the destination node!
	       ;;
	    d) daemon=true
	       ;;
	    P) run_wrapper=1
	       ;;
	    N) num_inst=$OPTARG
	       if [[ -z "$run_wrapper" ]]; then
		   echo "This option takes no effect without -P. Abort!"
		   exit 1
	       fi
	       verify_num_inst
	       ;;
	    I) iface=$OPTARG
	       if [[ -z "$run_wrapper" ]]; then
		   echo "This option takes no effect without -P. Abort!"
		   exit 1
	       fi	       
	       verify_iface
	       ;;
            v) verbose=1
               if [[ "$dry_run" ]]; then
                   echo "Warning: verbose mode shouldn't be used for dry-runs"
               fi
               ;;
	    n) dry_run=1
	       ;;
            *)  echo "Error: invalid option given!"
                exit 2
                ;;
        esac
    done
    if [[ "$ssh_port" ]]; then
	export RSYNC_RSH="ssh -p $ssh_port"
    fi    
    [[ -z "$dry_run" ]] && ensure_datasets_exist
    if [[ "$range_to_test" == 's' ]]; then
        losf_test
    elif [[ "$range_to_test" == 'm' ]]; then
        medium_file_test
    elif [[ "$range_to_test" == 'l' ]]; then
        large_file_test
    else
        losf_test
        medium_file_test
        large_file_test
    fi
    if ! [[ "$dry_run" ]]; then
	end_test=$(date +"%s")
	total_test_time=$((end_test-begin_test))
	echo ""
	ending="second"
	if [[ "$total_test_time" -gt 1 ]]; then
	    ending="seconds"
	fi
	echo "==> TOTAL test time (with cleaning): $total_test_time $ending"
    fi
    exit 0
} # end of main()
