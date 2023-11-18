BOARD="zybo-z720"
VIVADO_PROJ_NAME="rhd-spi"
VIVADO_PATH="${HOME}/Documents/Vivado/${VIVADO_PROJ_NAME}"
BD_WRAPPER_NAME="design_1_wrapper"

echo "Copying ${VIVADO_PROJ_NAME} outputs from ${VIVADO_PATH} into ${BOARD}"

cp "${VIVADO_PATH}/${BD_WRAPPER_NAME}.xsa" $BOARD
cp "${VIVADO_PATH}/${VIVADO_PROJ_NAME}.runs/impl_1/${BD_WRAPPER_NAME}.bit" $BOARD
find "${VIVADO_PATH}/${VIVADO_PROJ_NAME}.gen/sources_1/bd/design_1/hw_handoff/" -name \*.hwh -exec cp {} $BOARD \;
