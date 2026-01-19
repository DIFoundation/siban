// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Donation} from "../src/Donation.sol";
import {MembershipRegistration} from "../src/MembershipRegistration.sol";

contract DeployScript is Script {
    Donation public donation;
    MembershipRegistration public membershipRegistration;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        donation = new Donation(owner);
        membershipRegistration = new MembershipRegistration(owner);

        vm.stopBroadcast();
    }
}