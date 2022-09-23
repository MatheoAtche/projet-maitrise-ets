
# Copyright (c) 2020 Institution of Parallel and Distributed System, Shanghai Jiao Tong University
# ServerlessBench is licensed under the Mulan PSL v1.
# You can use this software according to the terms and conditions of the Mulan PSL v1.
# You may obtain a copy of Mulan PSL v1 at:
#     http://license.coscl.org.cn/MulanPSL
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
# PURPOSE.
# See the Mulan PSL v1 for more details.

import os
import threading
import time
import sys, getopt

def client(i,results,loopTimes):
    print("client %d start" %i)
    command = "./single-cold_warm.sh -l -R -t " + str(loopTimes)
    r = os.popen(command)  
    text = r.read()  
    results[i] = text
    print("client %d finished" %i)

def warmup(i,warmupTimes,actionName,params):
    print("client %d warming up" %i) 
    for j in range(warmupTimes):
        print("client %d, %d-th warm up" %(i,j+1))
        r = os.popen("wsk -i action invoke %s %s -r -b" %(actionName,params))  
        text = r.read() 
    print("client %d warmup finished" %i) 

def main():
    argv = getargv()
    clientNum = argv[0]
    loopTimes = argv[1]
    warmupTimes = argv[2]
    threads = []
    
    actionName = "arraySum_sequence"
    params = "--param n 0"

    s = os.popen("kubectl -n openwhisk get pods -l invoker -o name")
    if (s.read() != ""):
        print("killing pods before warmup")
        r = os.popen("kubectl -n openwhisk delete pods -l invoker")
        r.read()
        time.sleep(30)

    # First: warm up
    for i in range(clientNum):
        t = threading.Thread(target=warmup,args=(i,warmupTimes,actionName,params))
        threads.append(t)

    for i in range(clientNum):
        threads[i].start()

    for i in range(clientNum):
        threads[i].join()    
    print("Warm up complete")
    # Second: invoke the actions
    # Initialize the results and the clients
    threads = []
    results = []

    for i in range(clientNum):
        results.append('')

    # Create the clients
    for i in range(clientNum):
        t = threading.Thread(target=client,args=(i,results,loopTimes))
        threads.append(t)

    # start the clients
    for i in range(clientNum):
        threads[i].start()

    for i in range(clientNum):
        threads[i].join()


    outfile = open("result.csv","w")
    outfile.write("invokeTime,endTime,activationId,OW_SeqDuration,OwExecDuration\n")
   
    latencies = []
    OW_SeqDurations = []
    Ow_ExecDurations = []
    minInvokeTime = 0x7fffffffffffffff
    maxEndTime = 0
    for i in range(clientNum):
        # get and parse the result of a client
        clientResult = parseResult(results[i])
        # print the result of every loop of the client
        for j in range(len(clientResult)):
            outfile.write(clientResult[j][0] + ',' + clientResult[j][1] + ',' + clientResult[j][2] + ',' + clientResult[j][3] + '\n') 
        
            # Collect the latency
            latency = int(clientResult[j][1]) - int(clientResult[j][0])
            latencies.append(latency)
            OW_SeqDurations.append(int(clientResult[j][2]))
            Ow_ExecDurations.append(int(clientResult[j][3]))

            # Find the first invoked action and the last return one.
            if int(clientResult[j][0]) < minInvokeTime:
                minInvokeTime = int(clientResult[j][0])
            if int(clientResult[j][1]) > maxEndTime:
                maxEndTime = int(clientResult[j][1])
    formatResult(latencies, OW_SeqDurations, Ow_ExecDurations)

def parseResult(result):
    lines = result.split('\n')
    parsedResults = []
    for line in lines:
        if line.find("invokeTime") == -1:
            continue
        parsedTimes = ['','','','']
        values = line.split(',')
        i=0
        for value in values:
            parsedTimes[i] = value.split(':')[1]
            i+=1

        parsedResults.append(parsedTimes)
    return parsedResults

def getargv():
    if len(sys.argv) != 3 and len(sys.argv) != 4:
        print("Usage: python3 run.py <client number> <loop times> [<warm up times>]")
        exit(0)
    if not str.isdigit(sys.argv[1]) or not str.isdigit(sys.argv[2]) or int(sys.argv[1]) < 1 or int(sys.argv[2]) < 1:
        print("Usage: python3 run.py <client number> <loop times> [<warm up times>]")
        print("Client number and loop times must be an positive integer")
        exit(0)
    
    if len(sys.argv) == 4:
        if not str.isdigit(sys.argv[3]) or int(sys.argv[3]) < 1:
            print("Usage: python3 run.py <client number> <loop times> [<warm up times>]")
            print("Warm up times must be an positive integer")
            exit(0)

    else:
        return (int(sys.argv[1]),int(sys.argv[2]),1)

    return (int(sys.argv[1]),int(sys.argv[2]),int(sys.argv[3]))

def formatResult(latencies, OW_SeqDurations,OW_ExecDurations):
    resultfile = open("eval-result.log","a")
    resultfile.write("latencies : ")
    s = ""
    for i in latencies[:-1]:
        s = s + str(i) + ';'
    s = s + str(latencies[-1])
    resultfile.write(s)
    resultfile.write("\n")
    resultfile.write("OW_SeqDuration : ")
    s = ""
    for i in OW_SeqDurations[:-1]:
        s = s + str(i) + ';'
    s = s + str(OW_SeqDurations[-1])
    resultfile.write(s)
    resultfile.write("\n")
    resultfile.write("OW_ExecDuration : ")
    s = ""
    for i in OW_ExecDurations[:-1]:
        s = s + str(i) + ';'
    s = s + str(OW_ExecDurations[-1])
    resultfile.write(s)
    resultfile.write("\n")
main()