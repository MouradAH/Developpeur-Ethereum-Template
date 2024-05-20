// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Voting
 * @dev Contrat de vote permettant l'enregistrement des votants, l'enregistrement des propositions,
 * la session de vote, le décompte des votes et la détermination de la proposition gagnante.
 */
contract Voting is Ownable {
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    WorkflowStatus public workflowStatus;
    uint public winningProposalId;

    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    /**
     * @dev Constructor that sets the initial owner of the contract.
     * @param initialOwner The address of the initial owner.
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    /**
     * @dev Récupère le nombre de votes pour une proposition donnée.
     * @param proposalId L'identifiant de la proposition.
     * @return Le nombre de votes pour la proposition donnée.
     */
    function getVoteCountForProposal(uint proposalId) public view returns (uint) {
        require(proposalId < proposals.length, unicode"La proposition n'existe pas.");
        return proposals[proposalId].voteCount;
    }

    /**
     * @dev Enregistre un votant.
     * @param _voterAddress L'adresse du votant à enregistrer.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     * @dev Cette fonction ne peut être appelée que pendant la phase d'enregistrement des votants.
     * @dev Le votant ne peut être enregistré que s'il n'est pas déjà enregistré.
     */
    function registerVoter(address _voterAddress) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, unicode"Les votants ne peuvent être enregistrés que pendant la phase d'enregistrement des votants.");
        require(!voters[_voterAddress].isRegistered, unicode"Le votant est déjà enregistré.");
        voters[_voterAddress].isRegistered = true;
        emit VoterRegistered(_voterAddress);
    }

    /**
     * @dev Démarre la phase d'enregistrement des propositions.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     * @dev Cette fonction ne peut être appelée que pendant la phase d'enregistrement des votants.
     */
    function startProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, unicode"L'enregistrement des propositions ne peut être démarré qu'après l'enregistrement des votants.");
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * @dev Enregistre une proposition.
     * @param _description La description de la proposition.
     * @dev Cette fonction ne peut être appelée que pendant la phase d'enregistrement des propositions.
     * @dev Seuls les votants enregistrés peuvent enregistrer des propositions.
     */
    function registerProposal(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, unicode"Les propositions ne peuvent être enregistrées que pendant la phase d'enregistrement des propositions.");
        require(voters[msg.sender].isRegistered, unicode"Seuls les votants enregistrés peuvent enregistrer des propositions.");
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    /**
     * @dev Termine la phase d'enregistrement des propositions.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     */
    function endProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, unicode"La phase d'enregistrement des propositions doit être démarrée.");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * @dev Démarre la session de vote.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     * @dev Cette fonction ne peut être appelée que après l'enregistrement des propositions.
     */
    function startVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, unicode"La session de vote ne peut être démarrée qu'après l'enregistrement des propositions.");
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * @dev Termine la session de vote.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     */
    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, unicode"La session de vote doit être démarrée.");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * @dev Effectue un vote pour une proposition donnée.
     * @param _proposalId L'identifiant de la proposition.
     * @dev Cette fonction ne peut être appelée que pendant la session de vote.
     * @dev Seuls les votants enregistrés peuvent voter.
     * @dev Un votant ne peut voter qu'une seule fois.
     * @dev La proposition doit exister.
     */
    function vote(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, unicode"Les votes ne peuvent être effectués que pendant la session de vote.");
        require(voters[msg.sender].isRegistered, unicode"Seuls les votants enregistrés peuvent voter.");
        require(!voters[msg.sender].hasVoted, unicode"Le votant a déjà voté.");
        require(_proposalId < proposals.length, unicode"La proposition n'existe pas.");
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Décompte les votes et détermine la proposition gagnante.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     * @dev Cette fonction ne peut être appelée que après la session de vote.
     */
    function tallyVotes() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, unicode"Les votes ne peuvent être décomptés qu'après la session de vote.");
        workflowStatus = WorkflowStatus.VotesTallied;
        uint winningVoteCount = 0;
        uint winningProposalIndex = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalIndex = i;
            }
        }
        winningProposalId = winningProposalIndex;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

