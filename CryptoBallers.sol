pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2; // for returning struct from function

import './ERC721.sol';
import "github.com/Arachnid/solidity-stringutils/strings.sol"; // for string manipulations


contract CryptoBallers is ERC721 {

    using strings for *;

    struct Baller {
        string name;
        uint   level;
        uint   offenseSkill;
        uint   defenseSkill;
        uint   winCount;
        uint   lossCount;
    }

    address owner;
    Baller[] public ballers;

    // Mapping for if address has claimed their free baller
    mapping(address => bool) public claimedFreeBaller;

    // Fee for buying a baller
    uint ballerFee = 0.10 ether;

    /**
    * @dev Ensures ownership of the specified token ID
    * @param _tokenId uint256 ID of the token to check
    */
    modifier onlyOwnerOf(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Not owner of token");
        _;
    }

    /**
    * @dev Ensures ownership of contract
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner of contract");
        _;
    }

    /**
    * @dev Ensures baller has level above specified level
    * @param _level uint level that the baller needs to be above
    * @param _ballerId uint ID of the Baller to check
    */
    modifier aboveLevel(uint _level, uint _ballerId) {
        require(ballers[_ballerId].level > _level, "Not above required level");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /**
    * @dev Allows user to claim first free baller, ensure no address can claim more than one
    */
    function claimFreeBaller() public {
    
        require(claimedFreeBaller[msg.sender] == false, "already claimed free baller");

        // Extension: generate semi-random offense and defense values
        uint offense = random();
        uint defense = random();
        
        _createBaller("FreeBaller", 0, offense, defense);
        
        claimedFreeBaller[msg.sender] = true;
    }

    /**
    * @dev Allows user to buy baller with set attributes
    */
    function buyBaller() public payable {

        require(msg.sender.balance >= ballerFee, "insufficient funds");
        
        // ballerID is the index into ballers[]
        uint256 ballerID = ballers.length;

        string memory ballerName;
        ballerName = getBallerName(ballerID);

        // Extension: generate semi-random offense and defense values
        uint offense = random();
        uint defense = random();
        
        _createBaller(ballerName, 0, offense, defense);

        // pay fee
        msg.sender.balance.sub(ballerFee);
    }

    /**
    * @dev Play a game with your baller and an opponent baller
    * If your baller has more offensive skill than your opponent's defensive skill
    * you win, your level goes up, the opponent loses, and vice versa.
    * If you win and your baller reaches level 5, you are awarded a new baller with a mix of traits
    * from your baller and your opponent's baller.
    * @param _ballerId uint ID of the Baller initiating the game
    * @param _opponentId uint ID that the baller needs to be above
    */
    function playBall(uint _ballerId, uint _opponentId) public onlyOwnerOf(_ballerId) {

        uint level   = 0;
        uint attack  = 0;
        uint defense = 0;
        string memory name;
        
        // Note: if offenseSkill and defenseSkill of both players are both 0, _ballerId will always lose
        // this is where it would be good to have random values for offenseSkill and defenseSkill when building ballers

        if (ballers[_ballerId].offenseSkill > ballers[_opponentId].defenseSkill) {

            // baller wins / opponent loses

            ballers[_ballerId].level       += 1;
            ballers[_ballerId].winCount    += 1;
            ballers[_opponentId].lossCount += 1;

            if (ballers[_ballerId].level == 5) {

                (level, attack, defense) = _breedBallers(ballers[_ballerId], ballers[_opponentId]);

                name = getBallerName(_ballerId);

                _createBaller(name, level, attack, defense);
            }
        } else {

            // baller loses / opponent wins

            ballers[_opponentId].level    += 1;
            ballers[_opponentId].winCount += 1;
            ballers[_ballerId].lossCount  += 1;

            // not sure if this is necessary ...

            if (ballers[_opponentId].level == 5) {

                (level, attack, defense) = _breedBallers(ballers[_opponentId], ballers[_ballerId]);

                name = getBallerName(_opponentId);

                _createBaller(name, level, attack, defense);
            }
        }
    }

    /**
    * @dev Changes the name of your baller if they are above level two
    * @param _ballerId uint ID of the Baller who's name you want to change
    * @param _newName string new name you want to give to your Baller
    */
    function changeName(uint _ballerId, string _newName) external aboveLevel(2, _ballerId) onlyOwnerOf(_ballerId) {

        require(isStringEmpty(_newName), "invalid name");

        ballers[_ballerId].name = _newName;
    }

    /**
   * @dev Creates a baller based on the params given, adds them to the Baller array and mints a token
   * @param _name string name of the Baller
   * @param _level uint level of the Baller
   * @param _offenseSkill offensive skill of the Baller
   * @param _defenseSkill defensive skill of the Baller
   */
    function _createBaller(string _name, uint _level, uint _offenseSkill, uint _defenseSkill) internal {
       
        // !!! this is failing - not sure why - <_name> is not an empty string
        //require(isStringEmpty(_name), "invalid name");
    
        Baller memory baller;
        
        baller.name         = _name;
        baller.level        = _level;
        baller.offenseSkill = _offenseSkill;
        baller.defenseSkill = _defenseSkill;
        baller.winCount     = 0;
        baller.lossCount    = 0;
        
        ballers.push(baller);

        // create the index into ballers[] for the baller just created
        uint256 ballerID = ballers.length - 1;

        // mint a token for the baller just created
        _mint(msg.sender, ballerID);
    }

    /**
    * @dev Helper function for a new baller which averages the attributes of the level, attack, defense of the ballers
    * @param _baller1 Baller first baller to average
    * @param _baller2 Baller second baller to average
    * @return tuple of level, attack and defense
    */
    function _breedBallers(Baller _baller1, Baller _baller2) internal pure returns (uint, uint, uint) {

        uint level   = _baller1.level.add(_baller2.level).div(2);
        uint attack  = _baller1.offenseSkill.add(_baller2.offenseSkill).div(2);
        uint defense = _baller1.defenseSkill.add(_baller2.defenseSkill).div(2);
        
        return (level, attack, defense);
    }

    // Helper functions ---------------------------------------------------------

    // create unique baller name
    function getBallerName(uint ballerID) internal pure returns (string) {

        string memory ballerBase = "Baller";
        string memory ballerEnd;
        string memory ballerName;
        
        ballerEnd  = uint2str(ballerID);
        ballerName = ballerBase.toSlice().concat(ballerEnd.toSlice());

        return ballerName;
    }

    // convert uint to string
    function uint2str(uint i) internal pure returns (string) {
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint k = length - 1;
        while (i != 0) {
            bstr[k--] = byte(48 + i % 10);
            i /= 10;
        }
        return string(bstr);
    }

    function isStringEmpty(string i) internal pure returns (bool) {

        return i.toSlice().empty();
    }

    // Extension functions --------------------------------------------------------    

    // random number generator (not really random)
    function random() internal view returns (uint) {

        return uint(uint256(keccak256(block.timestamp, block.difficulty))%251);
    }

    // Get all of the tokens owned by a user
    // Note: returning a struct[] is only supported experimentally 
    // - must use <pragma experimental ABIEncoderV2;>
    // Note: contract won't deploy in JavascriptVM but is OK in Ganache
    
    function getAllBallers(address _user) public returns (Baller []) {

        Baller [] tokensOwned;

        // the idea is to loop through tokenIDs finding the ones which are
        // associated with the user address and saving them in a struct[]

        for (uint tokenID = 0; tokenID < ballers.length; tokenID++) {

            if (_user == ownerOf(tokenID)) {
                // save the token#
                tokensOwned.push(ballers[tokenID]);
            }
        }
        return tokensOwned;
    }
}