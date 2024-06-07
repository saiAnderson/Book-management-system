// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract LibrarySystem {
    struct Book {
        string title;
        string author;
        uint256 inventory;
        bool isAvailable;
    }

    struct BorrowInfo {
        uint256 borrowTime;
        uint256 returnTime;
        uint256 depositAmount;
    }

    struct Proposal {
        uint256 proposalId;  
        string title;
        string author;
        uint256 inventory;
        uint256 cost;
        address proposer;
        uint256 voteCount;
        bool executed;
    }

    address public libraryOwner;
    // type of books 
    uint256 public numBooks;
    uint256 public proposalCount;
    uint256 public totalMembers;
    
    // store books info  
    mapping(uint256 => Book) public books;
    
    // record the application is donate or not  
    mapping(address => bool) public members ;
    mapping(address => mapping(uint256 => BorrowInfo)) public borrowedBooks;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public votes;
    

    modifier onlyLibraryOwner() {
        require(msg.sender == libraryOwner, "Only the library owner can perform this action");
        _;
    }

    modifier onlyDonors() {
        require(members[msg.sender], "You need to donate to use the library");
        _;
    }

    constructor() {
        libraryOwner = msg.sender;
    }

    function getAllborrownum()public view returns(uint) {
        uint index = 0;
        for (uint i = 0; i < numBooks; i++) {
            if (borrowedBooks[msg.sender][i].borrowTime > 0) {
                index++;
            }
        }
        return index;
    }

    function addBook(string memory _title, string memory _author, uint256 _inventory) public {
        for (uint256 i = 0; i < numBooks; i++) {
            if (keccak256(bytes(books[i].title)) == keccak256(bytes(_title)) && keccak256(bytes(books[i].author)) == keccak256(bytes(_author))) {
                // If a book with the same title and author already exists, increase its inventory
                books[i].inventory += _inventory;
                books[i].isAvailable = true;
                return;
            }
        }
        books[numBooks] = Book(_title, _author, _inventory, true);
        numBooks++;
    }

    function donate() public payable {
        require(msg.value > 10 ether , "Donation amount must be greater than 10 ether");
        members[msg.sender] = true;
        totalMembers++;
    }

    function proposeNewBook(string memory _title, string memory _author, uint256 _inventory, uint256 _cost) public onlyDonors {
        proposals[proposalCount] = Proposal({
            proposalId: proposalCount,  // 設置 proposalId
            title: _title,
            author: _author,
            inventory: _inventory,
            cost: _cost,
            proposer: msg.sender,
            voteCount: 0,
            executed: false
        });
        proposalCount++;
    }

    function voteOnProposal(uint256 _proposalId) public onlyDonors {
        require(_proposalId < proposalCount, "Proposal does not exist");
        require(!votes[_proposalId][msg.sender], "You have already voted on this proposal");

        votes[_proposalId][msg.sender] = true;
        proposals[_proposalId].voteCount++;
    }

    function executeProposal(uint256 _proposalId) public onlyLibraryOwner {
        require(_proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.voteCount > totalMembers / 2, "Not enough votes");

        require(address(this).balance >= proposal.cost*10e17, "Not enough funds in the contract");

        payable(libraryOwner).transfer(proposal.cost*10e17);
        addBook(proposal.title, proposal.author, proposal.inventory);
        proposal.executed = true;
    }

    function getAllProposals() public view returns (Proposal[] memory) {
        Proposal[] memory allProposals = new Proposal[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            allProposals[i] = proposals[i];
        }
        return allProposals;
    }

    function borrowBook(uint256 _bookId, uint256 _borrowDuration) public payable onlyDonors {
        require(borrowedBooks[msg.sender][_bookId].depositAmount == 0, "You have borrowed this book");
        require(_bookId < numBooks, "Book does not exist");
        require(books[_bookId].isAvailable, "Book is not available");
        require(_borrowDuration >= 10 seconds && _borrowDuration <= 30 days, "Borrow duration must be between 10 seconds and 30 days");
        require(msg.value >= 1 ether, "Deposit amount must bigger than 1 ether");

        borrowedBooks[msg.sender][_bookId] = BorrowInfo(block.timestamp, block.timestamp + _borrowDuration, msg.value);
        books[_bookId].inventory--;
        if (books[_bookId].inventory == 0) {
            books[_bookId].isAvailable = false;
        }
    }

    function returnBook(uint256 _bookId) public {
        address temp = msg.sender;
        require(_bookId < numBooks, "Book does not exist");
        require(borrowedBooks[temp][_bookId].borrowTime > 0, "You have not borrowed this book");

        if (block.timestamp <= borrowedBooks[temp][_bookId].returnTime) {
            payable(temp).transfer(borrowedBooks[temp][_bookId].depositAmount);
        } else if (block.timestamp <= borrowedBooks[temp][_bookId].returnTime * 2) {
            payable(temp).transfer(borrowedBooks[temp][_bookId].depositAmount / 2);
        }

        books[_bookId].inventory++;
        if (books[_bookId].inventory > 0) {
            books[_bookId].isAvailable = true;
        }
        delete borrowedBooks[temp][_bookId];
    }

    function getBookId(string memory _title) public view returns (uint256) {
        for (uint256 i = 0; i < numBooks; i++) {
            if (keccak256(abi.encodePacked(books[i].title)) == keccak256(abi.encodePacked(_title))) {
                return i;
            }
        }
        revert("Book not found");
    }

    function getBorrowInfo(uint256 _bookId) public view returns (uint256 borrowTime, uint256 returnTime, uint256 depositAmount) {
        require(borrowedBooks[msg.sender][_bookId].borrowTime > 0, "You have not borrowed this book");
        BorrowInfo storage borrowInfo = borrowedBooks[msg.sender][_bookId];
        return (borrowInfo.borrowTime, borrowInfo.returnTime, borrowInfo.depositAmount);
    }

    // show all the books user borrowed
    function showAllBorrow() public view returns (string[] memory) {
        uint count = 0;
        for (uint i = 0; i < numBooks; i++) {
            if (borrowedBooks[msg.sender][i].borrowTime > 0) {
                count++;
            }
        }

        string[] memory borrowedBooksArray = new string[](count);
        uint index = 0;
        for (uint i = 0; i < numBooks; i++) {
            if (borrowedBooks[msg.sender][i].borrowTime > 0) {
                borrowedBooksArray[index] = books[i].title;
                index++;
            }
        }
        return borrowedBooksArray;
    }

    // show all the books in the libarary
    function showBooks() public view returns (Book[] memory) {
        Book[] memory allBooks = new Book[](numBooks);
        for (uint i = 0; i < numBooks; i++) {
            allBooks[i] = books[i];
        }
        return allBooks;
    }
}
