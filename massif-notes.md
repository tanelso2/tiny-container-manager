# View output
## ms_print
ms_print massif.out.20640

`.` - simple snapshot
`@` - detailed snapshot
`#` - peak snapshot
### Options
--x=72 - width of graph, in columns
--y=20 - height of the graph, in rows

## massif-visualizer 
- not bundled with valgrind, but is GUI

# Massif Options
--pages-as-heap=yes for tracking ALL memory usage

--stacks=yes for tracking stack memory

--depth=45 for longer callstacks in snapshots (default is 30)

--detailed-freq=<num> for changing frequency of detailed snapshots (default is 10, 1 means every snapshot is detailed)

--max-snapshots=<num> pretty self-explanatory. (Default is 100)

--time-unit=<i|ms|B>
default: i
i - instructions executed
ms - wall clock time
B - bytes allocated/deallocated