pragma solidity ^0.4.8;

contract Harmonauts {
    address owner;

    string public standard = 'CryptoHarmonauts';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    uint public nextHarmonautIndexToAssign = 0;

    bool public allHarmonautsAssigned = false;
    uint public HarmonautsRemainingToAssign = 0;

    //mapping (address => uint) public addressToHarmonautIndex;
    mapping(uint => address) public HarmonautIndexToAddress;

    /* This creates an array with all balances */
    mapping(address => uint256) public balanceOf;

    struct Offer {
        bool isForSale;
        uint HarmonautIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint HarmonautIndex;
        address bidder;
        uint value;
    }

    // A record of Harmonauts that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(uint => Offer) public HarmonautsOfferedForSale;

    // A record of the highest Harmonaut bid
    mapping(uint => Bid) public HarmonautBids;

    mapping(address => uint) public pendingWithdrawals;

    event Assign(address indexed to, uint256 HarmonautIndex);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event HarmonautTransfer(address indexed from, address indexed to, uint256 HarmonautIndex);
    event HarmonautOffered(uint indexed HarmonautIndex, uint minValue, address indexed toAddress);
    event HarmonautBidEntered(uint indexed HarmonautIndex, uint value, address indexed fromAddress);
    event HarmonautBidWithdrawn(uint indexed HarmonautIndex, uint value, address indexed fromAddress);
    event HarmonautBought(uint indexed HarmonautIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event HarmonautNoLongerForSale(uint indexed HarmonautIndex);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function Harmonauts() payable {
        //        balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        owner = msg.sender;
        totalSupply = 1000;
        // Update total supply
        HarmonautsRemainingToAssign = totalSupply;
        name = "Harmonauts";
        // Set the name for display purposes
        symbol = "HA";
        // Set the symbol for display purposes
        decimals = 0;
        // Amount of decimals for display purposes
    }

    function setInitialOwner(address to, uint HarmonautIndex) {
        if (msg.sender != owner) throw;
        if (allHarmonautsAssigned) throw;
        if (HarmonautIndex >= 1000) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != to) {
            if (HarmonautIndexToAddress[HarmonautIndex] != 0x0) {
                balanceOf[HarmonautIndexToAddress[HarmonautIndex]]--;
            } else {
                HarmonautsRemainingToAssign--;
            }
            HarmonautIndexToAddress[HarmonautIndex] = to;
            balanceOf[to]++;
            Assign(to, HarmonautIndex);
        }
    }

    function setInitialOwners(address[] addresses, uint[] indices) {
        if (msg.sender != owner) throw;
        uint n = addresses.length;
        for (uint i = 0; i < n; i++) {
            setInitialOwner(addresses[i], indices[i]);
        }
    }

    function allInitialOwnersAssigned() {
        if (msg.sender != owner) throw;
        allHarmonautsAssigned = true;
    }

    function getHarmonaut(uint HarmonautIndex) {
        if (!allHarmonautsAssigned) throw;
        if (HarmonautsRemainingToAssign == 0) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != 0x0) throw;
        if (HarmonautIndex >= 1000) throw;
        HarmonautIndexToAddress[HarmonautIndex] = msg.sender;
        balanceOf[msg.sender]++;
        HarmonautsRemainingToAssign--;
        Assign(msg.sender, HarmonautIndex);
    }

    // Transfer ownership of a Harmonaut to another user without requiring payment
    function transferHarmonaut(address to, uint HarmonautIndex) {
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != msg.sender) throw;
        if (HarmonautIndex >= 1000) throw;
        if (HarmonautsOfferedForSale[HarmonautIndex].isForSale) {
            harmonautNoLongerForSale(HarmonautIndex);
        }
        HarmonautIndexToAddress[HarmonautIndex] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, 1);
        HarmonautTransfer(msg.sender, to, HarmonautIndex);
        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = HarmonautBids[HarmonautIndex];
        if (bid.bidder == to) {
            // Kill bid and refund value
            pendingWithdrawals[to] += bid.value;
            HarmonautBids[HarmonautIndex] = Bid(false, HarmonautIndex, 0x0, 0);
        }
    }

    function harmonautNoLongerForSale(uint HarmonautIndex) {
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != msg.sender) throw;
        if (HarmonautIndex >= 10000) throw;
        HarmonautsOfferedForSale[HarmonautIndex] = Offer(false, HarmonautIndex, msg.sender, 0, 0x0);
        HarmonautNoLongerForSale(HarmonautIndex);
    }

    function offerHarmonautForSale(uint HarmonautIndex, uint minSalePriceInWei) {
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != msg.sender) throw;
        if (HarmonautIndex >= 10000) throw;
        HarmonautsOfferedForSale[HarmonautIndex] = Offer(true, HarmonautIndex, msg.sender, minSalePriceInWei, 0x0);
        HarmonautOffered(HarmonautIndex, minSalePriceInWei, 0x0);
    }

    function offerHarmonautForSaleToAddress(uint HarmonautIndex, uint minSalePriceInWei, address toAddress) {
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != msg.sender) throw;
        if (HarmonautIndex >= 10000) throw;
        HarmonautsOfferedForSale[HarmonautIndex] = Offer(true, HarmonautIndex, msg.sender, minSalePriceInWei, toAddress);
        HarmonautOffered(HarmonautIndex, minSalePriceInWei, toAddress);
    }

    function buyHarmonaut(uint HarmonautIndex) payable {
        if (!allHarmonautsAssigned) throw;
        Offer offer = HarmonautsOfferedForSale[HarmonautIndex];
        if (HarmonautIndex >= 1000) throw;
        if (!offer.isForSale) throw;
        // Harmonaut not actually for sale
        if (offer.onlySellTo != 0x0 && offer.onlySellTo != msg.sender) throw;
        // Harmonaut not supposed to be sold to this user
        if (msg.value < offer.minValue) throw;
        // Didn't send enough ETH
        if (offer.seller != HarmonautIndexToAddress[HarmonautIndex]) throw;
        // Seller no longer owner of Harmonaut

        address seller = offer.seller;

        HarmonautIndexToAddress[HarmonautIndex] = msg.sender;
        balanceOf[seller]--;
        balanceOf[msg.sender]++;
        Transfer(seller, msg.sender, 1);

        harmonautNoLongerForSale(HarmonautIndex);
        pendingWithdrawals[seller] += msg.value;
        HarmonautBought(HarmonautIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = HarmonautBids[HarmonautIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            HarmonautBids[HarmonautIndex] = Bid(false, HarmonautIndex, 0x0, 0);
        }
    }

    function withdraw() {
        if (!allHarmonautsAssigned) throw;
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function enterBidForHarmonaut(uint HarmonautIndex) payable {
        if (HarmonautIndex >= 1000) throw;
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] == 0x0) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] == msg.sender) throw;
        if (msg.value == 0) throw;
        Bid existing = HarmonautBids[HarmonautIndex];
        if (msg.value <= existing.value) throw;
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        HarmonautBids[HarmonautIndex] = Bid(true, HarmonautIndex, msg.sender, msg.value);
        HarmonautBidEntered(HarmonautIndex, msg.value, msg.sender);
    }

    function acceptBidForHarmonaut(uint HarmonautIndex, uint minPrice) {
        if (HarmonautIndex >= 1000) throw;
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] != msg.sender) throw;
        address seller = msg.sender;
        Bid bid = HarmonautBids[HarmonautIndex];
        if (bid.value == 0) throw;
        if (bid.value < minPrice) throw;

        HarmonautIndexToAddress[HarmonautIndex] = bid.bidder;
        balanceOf[seller]--;
        balanceOf[bid.bidder]++;
        Transfer(seller, bid.bidder, 1);

        HarmonautsOfferedForSale[HarmonautIndex] = Offer(false, HarmonautIndex, bid.bidder, 0, 0x0);
        uint amount = bid.value;
        HarmonautBids[HarmonautIndex] = Bid(false, HarmonautIndex, 0x0, 0);
        pendingWithdrawals[seller] += amount;
        HarmonautBought(HarmonautIndex, bid.value, seller, bid.bidder);
    }

    function withdrawBidForHarmonaut(uint HarmonautIndex) {
        if (HarmonautIndex >= 1000) throw;
        if (!allHarmonautsAssigned) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] == 0x0) throw;
        if (HarmonautIndexToAddress[HarmonautIndex] == msg.sender) throw;
        Bid bid = HarmonautBids[HarmonautIndex];
        if (bid.bidder != msg.sender) throw;
        HarmonautBidWithdrawn(HarmonautIndex, bid.value, msg.sender);
        uint amount = bid.value;
        HarmonautBids[HarmonautIndex] = Bid(false, HarmonautIndex, 0x0, 0);
        // Refund the bid money
        msg.sender.transfer(amount);
    }
}
