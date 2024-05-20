SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Voting
 * @dev Contrat de vote permettant l'enregistrement des votants, l'enregistrement des propositions,
 * la session de vote et le décompte des votes.
 */
contract Voting is Ownable {
    /**
     * @dev Enumération représentant les différentes étapes du processus de vote.
     */
    enum WorkflowStatus {
        RegisteringVoters,               // Inscription des votants
        ProposalsRegistrationStarted,    // Début de l'enregistrement des propositions
        ProposalsRegistrationEnded,      // Fin de l'enregistrement des propositions
        VotingSessionStarted,            // Début de la session de vote
        VotingSessionEnded,              // Fin de la session de vote
        VotesTallied,                    // Décompte des votes terminé
        RunoffVotingStarted,             // Début du second tour de vote
        RunoffVotingEnded                // Fin du second tour de vote
    }

    /**
     * @dev Structure représentant un votant.
     */
    struct Voter {
        bool isRegistered;      // Indique si le votant est enregistré
        bool hasVoted;          // Indique si le votant a voté
        uint votedProposalId;   // Identifiant de la proposition pour laquelle le votant a voté
    }

    /**
     * @dev Structure représentant une proposition.
     */
    struct Proposal {
        string description;     // Description de la proposition
        uint voteCount;         // Nombre de votes pour cette proposition
    }

    mapping(address => Voter) public voters;    // Mapping des adresses des votants vers les structures Voter
    Proposal[] public proposals;                // Tableau des propositions
    WorkflowStatus public workflowStatus;       // Statut actuel du workflow
    uint[] public winningProposalIds;           // Tableau des identifiants des propositions gagnantes
    uint[] public runoffProposals;              // Tableau des propositions du second tour

    event VoterRegistered(address voterAddress);                       
    event VoterRevoked(address voterAddress);                          
    event ProposalRegistered(uint proposalId);                         
    event ProposalDeleted(uint proposalId);                            
    event Voted(address voter, uint proposalId);                       
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    /**
     * @dev Constructeur du contrat Voting.
     * @param initialOwner Adresse du propriétaire initial du contrat.
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    /**
     * @dev Récupère le nombre de votes pour une proposition donnée.
     * @param proposalId L'identifiant de la proposition.
     * @return Le nombre de votes pour la proposition.
     */
    function getVoteCountForProposal(uint proposalId) public view returns (uint) {
        require(proposalId < proposals.length, "Invalid proposal.");
        return proposals[proposalId].voteCount;
    }

    /**
     * @dev Enregistre un votant.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     * @param _voterAddress L'adresse du votant à enregistrer.
     */
    function registerVoter(address _voterAddress) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Voters can only be registered during the registering voters phase.");
        require(!voters[_voterAddress].isRegistered, "Voter is already registered.");

        voters[_voterAddress].isRegistered = true;

        emit VoterRegistered(_voterAddress);
    }

    /**
     * @dev Révoque un votant.
     * @param _voterAddress L'adresse du votant à révoquer.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function revokeVoter(address _voterAddress) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Voters can only be revoked during the registering voters phase.");
        require(voters[_voterAddress].isRegistered, "Voter is not registered.");

        voters[_voterAddress].isRegistered = false;

        emit VoterRevoked(_voterAddress);
    }

    /**
     * @dev Démarre la phase d'enregistrement des propositions.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function startProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Proposals registration can only be started after registering voters.");

        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * @dev Termine la phase d'enregistrement des propositions.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function endProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration phase must be started.");

        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * @dev Enregistre une proposition.
     * @param _description La description de la proposition.
     * Seuls les votants enregistrés peuvent enregistrer des propositions.
     */
    function registerProposal(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals can only be registered during the proposals registration phase.");
        require(voters[msg.sender].isRegistered, "Only registered voters can register proposals.");

        proposals.push(Proposal(_description, 0));

        emit ProposalRegistered(proposals.length - 1);
    }

    /**
     * @dev Supprime une proposition.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     * @param proposalId L'identifiant de la proposition à supprimer.
     */
    function deleteProposal(uint proposalId) public onlyOwner {
        require(proposalId < proposals.length, "Invalid proposal.");
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals can only be deleted during the proposals registration phase.");

        for (uint i = proposalId; i < proposals.length - 1; i++) {
            proposals[i] = proposals[i + 1];
        }
        proposals.pop();

        emit ProposalDeleted(proposalId);
    }

    /**
     * @dev Démarre la session de vote.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function startVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Voting session can only be started after proposals registration.");

        workflowStatus = WorkflowStatus.VotingSessionStarted;

        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * @dev Termine la session de vote.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session must be started.");

        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * @dev Enregistre un vote pour une proposition donnée.
     * @param _proposalId L'identifiant de la proposition.
     * Seuls les votants enregistrés peuvent voter.
     */
    function vote(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Votes can only be cast during the voting session.");
        require(voters[msg.sender].isRegistered, "Only registered voters can vote.");
        require(!voters[msg.sender].hasVoted, "Voter has already voted.");
        require(_proposalId < proposals.length, "Invalid proposal.");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Effectue le décompte des votes.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function tallyVotes() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Votes can only be tallied after the voting session.");

        uint winningVoteCount = 0;
        winningProposalIds = new uint  ;

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalIds = new uint  ;
                winningProposalIds.push(i);
            } else if (proposals[i].voteCount == winningVoteCount) {
                winningProposalIds.push(i);
            }
        }

        if (winningProposalIds.length > 1) {
            runoffProposals = winningProposalIds;
            workflowStatus = WorkflowStatus.RunoffVotingStarted;
            emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.RunoffVotingStarted);
        } else {
            workflowStatus = WorkflowStatus.VotesTallied;
            emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        }
    }

    /**
     * @dev Enregistre un vote pour une proposition lors du second tour.
     * @param _proposalId L'identifiant de la proposition.
     * Seuls les votants enregistrés peuvent voter.
     */
   

 function runoffVote(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.RunoffVotingStarted, "Votes can only be cast during the runoff voting session.");
        require(voters[msg.sender].isRegistered, "Only registered voters can vote.");
        require(!voters[msg.sender].hasVoted, "Voter has already voted.");
        require(_proposalId < runoffProposals.length, "Invalid proposal.");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Termine le second tour de vote.
     * Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function endRunoffVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RunoffVotingStarted, "Runoff voting session must be started.");

        uint winningVoteCount = 0;
        winningProposalIds = new uint ;

        for (uint i = 0; i < runoffProposals.length; i++) {
            uint proposalId = runoffProposals[i];
            if (proposals[proposalId].voteCount > winningVoteCount) {
                winningVoteCount = proposals[proposalId].voteCount;
                winningProposalIds = new uint  ;
                winningProposalIds.push(proposalId);
            } else if (proposals[proposalId].voteCount == winningVoteCount) {
                winningProposalIds.push(proposalId);
            }
        }

        if (winningProposalIds.length > 1) {
            // If still tied after runoff voting, administrator decides the winner
            workflowStatus = WorkflowStatus.RunoffVotingEnded;
            emit WorkflowStatusChange(WorkflowStatus.RunoffVotingStarted, WorkflowStatus.RunoffVotingEnded);
        } else {
            workflowStatus = WorkflowStatus.VotesTallied;
            emit WorkflowStatusChange(WorkflowStatus.RunoffVotingStarted, WorkflowStatus.VotesTallied);
        }
    }

    function getProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    function getWinner() public view returns (uint[] memory, string[] memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied || workflowStatus == WorkflowStatus.RunoffVotingEnded, "Votes must be tallied or runoff voting ended before getting the winner.");
        require(winningProposalIds.length > 0, "No winning proposal.");

        uint[] memory winnerIds = new uint  (winningProposalIds.length);
        string[] memory winners = new string  (winningProposalIds.length);
        for (uint i = 0; i < winningProposalIds.length; i++) {
            winnerIds[i] = winningProposalIds[i];
            winners[i] = proposals[winningProposalIds[i]].description;
        }
        return (winnerIds, winners);
    }

    /**
     * @dev L'administrateur décide du gagnant parmi les propositions à égalité après le second tour.
     * @param _proposalId L'identifiant de la proposition gagnante choisie par l'administrateur.
     */
    function decideTie(uint _proposalId) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RunoffVotingEnded, "Tie can only be decided after runoff voting ended.");
        require(_proposalId < proposals.length, "Invalid proposal.");
        require(proposals[_proposalId].voteCount == proposals[winningProposalIds[0]].voteCount, "Chosen proposal must be among the tied ones.");

        winningProposalIds = new uint (1) ;
        winningProposalIds[0] = _proposalId;
        workflowStatus = WorkflowStatus.VotesTallied;

        emit WorkflowStatusChange(WorkflowStatus.RunoffVotingEnded, WorkflowStatus.VotesTallied);
    }
}
```
