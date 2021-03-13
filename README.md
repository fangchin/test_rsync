## March 14, 2021

![Test rsync logo](pics/rsync_examined.png)

Chin Fang <`fangchin[at]zettar.com`>, Palo Alto, California, U.S.A  
[Programming is Gardening, not
Engineering](https://www.artima.com/intv/garden.html) 

<a name="page_top"></a>
Table of contents
=================

   * [Introduction](#introduction)
   * [Requirements](#requirements)
   * [Examples](#examples)
      * [rsync WAN test dry-run](#rsync-wan-test-dry-run)
	  * [rsync and rsyncd LAN test dry-run](#rsync-and-rsyncd-lan-test-dry-run)
	  * [parsyncfp-lan-test-dry-run](#parsyncfp-lan-test-dry-run)
   * [Motivation](#motivation)
   * [Goals](#goals)
   * [Possible-uses](#possible-uses)   
   * [References](#references)
   
# Introduction

This directory contains two `bash` scripts:

1. **`trsync.sh`** is a wrapper script of `rsync`, `rsyncd`, and
   [`parsyncfp`](https://github.com/hjmangalam/parsyncfp).  Its main
   purpose is enable automated testing of the above three as easily as
   possible.  Once it's installed, type `trsync.sh -h` for more info.
2. **`harness.sh`** is a wrapper script for `trsync.sh`. Once it's
   installed, type `harness.sh -h` for more info.
   
[Back to top](#page_top)
   
# Requirements
1. The `rsync` is installed on both the source and target systems.
2. The `rsyncd` (aka `rsync` daemon) is installed and properly set up
   on the desired target system.
3. The `parsyncfp` is set up according to the tool's instructions.
   Should you have any questions about this tool, please [open a new
   issue](https://github.com/hjmangalam/parsyncfp/issues/new) at the
   tool's github repo. We don't collaborate with the authors.

[Back to top](#page_top)

# Examples

The two `bash` scripts have been written to be almost as readable as
English.  Both are implemented with a dry-run mode to facilitate the
learning of proper use and possible extension.

## rsync WAN test dry-run

```
[root@zh0 ~]# harness.sh -t wan -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -n 
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data  -r s | tee /var/tmp/rsync_wan'_losf.out'
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data  -r m | tee /var/tmp/rsync_wan'_medium.out'
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data  -r l | tee /var/tmp/rsync_wan'_large.out'

==> TOTAL test time (with cleaning): 0 second
```
[Back to top](#page_top)

## rsync and rsyncd LAN test dry-run
```
[root@zh0 ~]# harness.sh -t lan -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -n -d
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -d -r s | tee /var/tmp/rsync_lan'_losf.out'
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -d -r m | tee /var/tmp/rsync_lan'_medium.out'
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -d -r l | tee /var/tmp/rsync_lan'_large.out'

==> TOTAL test time (with cleaning): 0 second
```
[Back to top](#page_top)

## parsyncfp LAN test dry-run
```
[root@zh0 ~]# harness.sh -t lan -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -n -P -I enp175s0f0 -C 12
6 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 6 -a 0 | tee /var/tmp/parsyncfp_lan_losf.06
8 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 8 -a 0 | tee /var/tmp/parsyncfp_lan_losf.08
10 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 10 -a 0 | tee /var/tmp/parsyncfp_lan_losf.010
12 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 12 -a 0 | tee /var/tmp/parsyncfp_lan_losf.012
6 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 6 -a 1 | tee /var/tmp/parsyncfp_lan_losf.16
8 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 8 -a 1 | tee /var/tmp/parsyncfp_lan_losf.18
10 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 10 -a 1 | tee /var/tmp/parsyncfp_lan_losf.110
12 rsync instances
trsync.sh -i 192.168.15.20 -S /var/local/zettar/zx/src_data -D /var/local/zettar/zx/dst_data -P -I enp175s0f0 -r s -N 12 -a 1 | tee /var/tmp/parsyncfp_lan_losf.112
[...]
==> TOTAL test time (with cleaning): 1 second
```
[Back to top](#page_top)

# Motivation

*The following is excerpted from an upcoming U.S. DOE Technical
Report, "**When to use rsync**".  Once the report is published, it
will be linked in here*.

`Rsync` was co-created by [Andrew Tridgell and Paul
Mackerras](https://en.wikipedia.org/wiki/Andrew_Tridgell) in the early
1990s, partially for [Andrew’s
Ph.D. dissertation](https://www.samba.org/~tridge/phd_thesis.pdf) and
partially for [backing up his wife’s system](
https://download.samba.org/pub/rsync/rsync.1).  From such a modest
beginning, it has gained worldwide popularity and is bundled with all
major Linux distributions.  It is often regarded as the go-to data
mover tool by many enterprise IT professionals.  Despite its
popularity, the tool’s various problems in dealing with many small
files or very large files and large network latencies are well-known,
as a casual search would reveal.  There are also some attempts to
address these shortcomings via the approach of aggregation, typically
using a wrapper to run multiple `rsync` instances at the same time.  A
good example is `parsyncfp`.

Nevertheless, there have been no systematic investigations about
`rsync`’s proper range of operation.  The [rsync man
page](https://download.samba.org/pub/rsync/rsync.1) only states,
quoted "rsync -⁠ a fast, versatile, remote (and local) file-copying
tool", *but neither "fast" nor "remote" are precisely defined*.  The
effectiveness of using the aggregation approach via a wrapper is also
not clear.  This report intends to address the lack of knowledge in
this regard.  Specifically, the report intends to answer this
question: "**in today’s data-centric world, when to use rsync**" (*with or
without using a wrapper*)?  The answer is based on the results obtained
from a series of automated tests transferring files using two
testbeds.  Both LAN and WAN transfer results are analyzed to show the
proper range of use for rsync-based tools.

[Back to top](#page_top)

# Goals

The major goal is to inform and educate the public, especially
enterprise IT professionals, that `rsync` is still a good tool, but it
is not a tool for moving hyperscale datasets over a network with round
trip time (RTT) >= 10ms, where the term "hyperscale dataset" is
defined as a dataset that has >= 1M files, or
overall size >= 1TB, or both.  

The author has witnessed first hand at various data-intensive
enterprises, e.g. large biopharmaceutical businesses, that some IT
people still believe that `rsync` can be used for file system data
migration involving multiple PBs' of data!  This kind of
misconceptions should be purged.  We all live once - our life is
too precious to wate!

For these, once the aforemtioned DOE Technical Report is published,
please consult it for alternatives.

[Back to top](#page_top)

# Possible uses

Since `rsync` based tools are really not for high-performance moving
data at scale and speed, so although the investigation carried out for
the aforementioned DOE Technical Report has been carried out as
extensively as possible, the long running time taken by most of the
transfer tests simply renders the use of the employed test envionments
impractical - they both have other important projects waiting.

Thus, the two tester scripts are made freely available, so that
curious parties can use them in their respective environment to obtain
their own results and draw concrete, number-based conclusions rather
than just heresays.

[Back to top](#page_top)

# References

1. [Chin Fang, "High-Performance Data Movement Services - DTNaaS",
   Rice 2021 Oil & Gas High-Performance Conference Technical Program
   Lightning talk, March 5,
   2021](https://youtube.com/watch?v=f5C2b7aYlnk) - any enterprise IT
   professional who moves data frequently should foremost gain a good
   understanding about how to benchmark a file storage service, then
   about computing and networking (including network security
   basics). This lightning talk provides some basics and best
   practices.  **Warning**! Anyone who considers moving data at scale
   and/or speed as a software or network alone task will be running a
   fool's errand.
2. [Sven Breuner, "elbencho, A distributed storage benchmark for file
   systems and block devices with support for
   GPUs](https://github.com/breuner/elbencho) - the best and easiest
   to use storage benchmark. Free too!
3. [Chin Fang, "elbencho storage sweep
   tools"](https://github.com/breuner/elbencho/tree/master/contrib/storage_sweep) -
   easy button approach to gain insight about a complex file storage
   service.
4. [Sven Breune, Chin Fang, "elbencho - A new Storage Benchmark for AI
   et al", PPoPP'21 Workshop: Benchmarking in the Data
   Center"](https://parallel.computer/presentations/PPoPP2021/elbenchoANewStorageBenchmarkForAIetal.pdf) -
   a short and sweet presentation about storage benchmarking with
   elbencho.

[Back to top](#page_top)
