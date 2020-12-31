#---------------------------------------------------------
# Now resynthesize the design to meet constraints,     
# and try to best achieve the goal, and using the      
# CMOSX parts.  In large designs, compile can take     
# a lllooonnnnggg time!                                
#
# -map_effort specifies how much optimization effort   
# there is, i.e. low, medium, or high.                 
#		Use high to squeeze out those last picoseconds. 
# -verify_effort specifies how much effort to spend    
# making sure that the input and output designs        
# are equivalent logically                             
#---------------------------------------------------------
##################################################
# Revision History: 01/18/2011, by Zhuo Yan
# replaced with ultra: 08/21/2020, by P. Franzon
##################################################

###########################
# old command - still works, is probably faster but less optimal
# compile -map_effort medium
###########################

compile_ultra

#---------------------------------------------------------
# This is just a sanity check: Write out the design before 
# hold fixing
#---------------------------------------------------------
 write -hierarchy -f verilog -o ${modname}_init.v

#---------------------------------------------------------
# Now trace the critical (slowest) path and see if     
# the timing works.                                    
# If the slack is NOT met, you HAVE A PROBLEM and      
# need to redesign or try some other minimization      
# tricks that Synopsys can do                          
#---------------------------------------------------------

 report_timing  > timing_max_slow.rpt

#---------------------------------------------------------
# This is your section to do different things to       
# improve timing or area - RTFM (Read The Manual) :)
#---------------------------------------------------------
