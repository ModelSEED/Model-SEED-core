# ---------------------------------------------------------------------
# Directories section 
# ---------------------------------------------------------------------
SRCDIR = $(MFATOOLKITDIR)Source/
# ---------------------------------------------------------------------
# Compiler section 
# ---------------------------------------------------------------------
CCC = g++
# ---------------------------------------------------------------------
# Compiler options 
# ---------------------------------------------------------------------
SRCFILES = $(SRCDIR)/driver.cpp $(SRCDIR)/MFAProblem.cpp $(SRCDIR)/$(CPLEXAPI) $(SRCDIR)/SCIPapi.cpp $(SRCDIR)/GLPKapi.cpp $(SRCDIR)/LINDOapiEMPTY.cpp $(SRCDIR)/SolverInterface.cpp $(SRCDIR)/Species.cpp $(SRCDIR)/Data.cpp $(SRCDIR)/InterfaceFunctions.cpp $(SRCDIR)/Identity.cpp $(SRCDIR)/Reaction.cpp $(SRCDIR)/GlobalFunctions.cpp $(SRCDIR)/AtomCPP.cpp $(SRCDIR)/UtilityFunctions.cpp $(SRCDIR)/AtomType.cpp $(SRCDIR)/Gene.cpp $(SRCDIR)/GeneInterval.cpp $(SRCDIR)/stringDB.cpp

OBJFILES = $(SRCFILES:.cpp=.o)

MFATOOLKIT: $(OBJFILES)
	$(CCC) $(MFATOOLKITCCFLAGS) -o $(MFATOOLKITDIR)Linux/mfatoolkit $(^) $(MFATOOLKITCCLNFLAGS)

%.o: %.cpp
	$(CCC) $(MFATOOLKITCCFLAGS) -c $<; mv *.o ../Source

clean:
	rm -f $(SRCDIR)/*.o $(MFATOOLKITDIR)Linux/mfatoolkit