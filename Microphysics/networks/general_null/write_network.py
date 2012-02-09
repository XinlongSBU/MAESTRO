#!/usr/bin/env python

import sys
import string
import getopt
import os.path

Header="""
! DO NOT EDIT THIS FILE!!!  
!  
! This file is automatically generated by write_network.py at 
! compile-time.  
!  
! To modify the species carried by the network, edit the appropriate inputs 
! file.

"""


#=============================================================================
# the species class holds the properties of a single species
#=============================================================================
class species:

    def __init__(self):
        self.name = ""
        self.shortName = ""
        self.A = -1
        self.Z = -1


#=============================================================================
# getNextLine returns the next, non-blank line, with comments stripped
#=============================================================================
def getNextLine(fin):

    line = fin.readline()

    pos = str.find(line, "#")

    while ((pos == 0) or (str.strip(line) == "") and line):

        line = fin.readline()
        pos = str.find(line, "#")

    line = line[:pos]

    return line



#=============================================================================
# getSpeciesIndex looks through the list and returns the index corresponding to
# the species specified by name
#=============================================================================
def getSpeciesIndex(speciesList, name):

    index = -1

    n = 0
    while (n < len(speciesList)):
        
        if (speciesList[n].name == name):
            index = n
            break

        n += 1

    return index



#=============================================================================
# parseNetFile read all the species listed in a given network inputs file
# and adds the valid species to the species list
#=============================================================================
def parseNetFile(speciesList, netFile, networkLocation):

    err = 0

    try: f = open(netFile, "r")
    except IOError:

        print("write_network.py: WARNING: file "+str(netFile)+" does not exist")
        netFile = os.path.join(networkLocation, netFile)
        print("write_network.py: WARNING: trying file "+str(netFile))

        try: f = open(netFile, "r")
        except IOError:
            print("write_network.py: ERROR: file "+str(netFile)+" does not exist")
            sys.exit(2)
        
    print("write_network.py: working on network file "+str(netFile)+"...")

    line = getNextLine(f)

    while (line and not err):

        fields = line.split()

        if (not (len(fields) == 4)):
            print(line)
            print("write_network.py: ERROR: missing one or more fields in species definition.")
            err = 1
            continue

        currentSpecies = species()
            
        currentSpecies.name      = fields[0]
        currentSpecies.shortName = fields[1]
        currentSpecies.A         = fields[2]
        currentSpecies.Z         = fields[3]


        # check to see if this species is defined in the current list
        index = getSpeciesIndex(speciesList, currentSpecies.name)

        if (index >= 0):
            print("write_network.py: ERROR: species %s already defined." % 
                  (currentSpecies.name))
            err = 1                


            
        speciesList.append(currentSpecies)

        line = getNextLine(f)

    return err


#=============================================================================
# abort exits when there is an error.  A dummy stub file is written out, which
# will cause a compilation failure
#=============================================================================
def abort(outfile):

    fout = open(outfile, "w")
    fout.write("There was an error parsing the network files")
    fout.close()
    sys.exit(1)

    

#=============================================================================
# write_network will read through the list of species and output the 
# new outFile
#=============================================================================
def write_network(networkTemplate, netFile, outFile):

    speciesList = []

    print(" ")
    print("write_network.py: creating %s" % (outFile))

    networkLocation = os.path.dirname(networkTemplate)


    #-------------------------------------------------------------------------
    # read the species defined in the netFile
    #-------------------------------------------------------------------------
    err = parseNetFile(speciesList, netFile, networkLocation)
        
    if (err):
        abort(outFile)


    #-------------------------------------------------------------------------
    # open up the template
    #-------------------------------------------------------------------------
    try: ftemplate = open(networkTemplate, "r")
    except IOError:
        print("write_network.py: ERROR: file "+str(networkTemplate)+" does not exist")
        sys.exit(2)
    else:
        ftemplate.close()

    ftemplate = open(networkTemplate, "r")

    templateLines = []
    line = ftemplate.readline()
    while (line):
        templateLines.append(line)
        line = ftemplate.readline()


    #-------------------------------------------------------------------------
    # output the template, inserting the species info in between the @@...@@
    #-------------------------------------------------------------------------
    fout = open(outFile, "w")

    fout.write(Header)

    for line in templateLines:

        index = line.find("@@")

        if (index >= 0):
            index2 = line.rfind("@@")

            keyword = line[index+len("@@"):index2]
            indent = index*" "

            if (keyword == "NSPEC"):

                fout.write(string.replace(line,"@@NSPEC@@", str(len(speciesList))))

            elif (keyword == "SPEC_NAMES"):

                n = 0
                while (n < len(speciesList)):

                    fout.write("%sspec_names(%d) = \"%s\"\n" % 
                               (indent, n+1, speciesList[n].name))

                    n += 1


            elif (keyword == "SHORT_SPEC_NAMES"):

                n = 0
                while (n < len(speciesList)):

                    fout.write("%sshort_spec_names(%d) = \"%s\"\n" % 
                               (indent, n+1, speciesList[n].shortName))

                    n += 1


            elif (keyword == "AION"):

                n = 0
                while (n < len(speciesList)):

                    fout.write("%saion(%d) = %s\n" % 
                               (indent, n+1, speciesList[n].A))

                    n += 1


            elif (keyword == "ZION"):

                n = 0
                while (n < len(speciesList)):

                    fout.write("%szion(%d) = %s\n" % 
                               (indent, n+1, speciesList[n].Z))

                    n += 1

        else:
            fout.write(line)


    
    print(" ")
    fout.close()




if __name__ == "__main__":

    try: opts, next = getopt.getopt(sys.argv[1:], "t:o:s:")

    except getopt.GetoptError:
        print("write_network.py: invalid calling sequence")
        sys.exit(2)

    networkTemplate = ""
    outFile = ""
    netFile = ""

    for o, a in opts:

        if o == "-t":
            networkTemplate = a

        if o == "-o":
            outFile = a

        if o == "-s":
            netFile = a


    if (networkTemplate == "" or outFile == ""):
        print("write_probin.py: ERROR: invalid calling sequence")
        sys.exit(2)

    write_network(networkTemplate, netFile, outFile)



