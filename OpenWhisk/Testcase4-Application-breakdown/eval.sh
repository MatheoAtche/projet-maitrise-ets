#!/bin/bash
#
# Copyright (c) 2020 Institution of Parallel and Distributed System, Shanghai Jiao Tong University
# ServerlessBench is licensed under the Mulan PSL v1.
# You can use this software according to the terms and conditions of the Mulan PSL v1.
# You may obtain a copy of Mulan PSL v1 at:
#     http://license.coscl.org.cn/MulanPSL
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
# PURPOSE.
# See the Mulan PSL v1 for more details.
#

result=eval-result.log
rm -f $result

export TESTCASE4_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $TESTCASE4_HOME

function runImage() {
    echo "measuring image-process application..."
    cd image-process
    ./scripts/eval.sh
    cd $TESTCASE4_HOME
    echo -e "\n\n>>>>>>>> image-process <<<<<<<<\n" >> $result
    cat image-process/$result >> $result
}

runImage

echo "serverless applications result: "
cat $result

