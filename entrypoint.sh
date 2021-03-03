#!/bin/bash
set -e
echo -e "#!/bin/bash\n\n" > run.sh
echo "${INPUT_CMD}" > run.sh;
chmod +x ./run.sh;
./run.sh;
