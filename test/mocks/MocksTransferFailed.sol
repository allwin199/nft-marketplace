// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

contract MocksTransferFailed {
    fallback() external payable {
        revert();
    }
}
