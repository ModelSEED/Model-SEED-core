This readme file explains the purpose of every binary included in this directory.
ModelDriver.sh: this shell script runs the ModelDriver.pl script that is called by the job pipeline to run all ModelSEED commands utilized in the pipeline.
QueueDriver.sh: this shell script run the FIGMODELschedule.pl script that actually manages the job queue by starting jobs, monitoring jobs, and killing jobs when needed.
StartScheduler.sh: this shell script calls QueueDriver.sh in "nohup" mode for each of the distinct queues being maintained (e.g. slow, fast, cplex..). This script should be called if one of the job pipelines has crashed for some reason.
UpdateModelSEED.sh: this shell script does a git pull and make on the production ModelSEED perl code.
