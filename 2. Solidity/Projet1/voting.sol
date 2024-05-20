// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Importation du contrat Ownable depuis OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Voting
 * @dev Contrat de vote permettant l'enregistrement des votants, l'enregistrement des propositions,
 * la session de vote, le décompte des votes et la détermination de la proposition gagnante.
 */
contract Voting is Ownable {
    
    // Enumération représentant les différentes étapes du processus de vote.
    enum WorkflowStatus {
        RegisteringVoters,               // Inscription des votants
        ProposalsRegistrationStarted,    // Début de l'enregistrement des propositions
        ProposalsRegistrationEnded,      // Fin de l'enregistrement des propositions
        VotingSessionStarted,            // Début de la session de vote
        VotingSessionEnded,              // Fin de la session de vote
        VotesTallied                     // Décompte des votes terminé
    }

    // Structure représentant un votant.
    struct Voter {
        bool isRegistered;  // Indique si le votant est enregistré
        bool hasVoted;      // Indique si le votant a voté
        uint votedProposalId; // Identifiant de la proposition pour laquelle le votant a voté
    }

    // Structure représentant une proposition.
    struct Proposal {
        string description; // Description de la proposition
        uint voteCount;     // Nombre de votes pour cette proposition
    }

    // Mapping des adresses des votants vers les structures Voter
    mapping(address => Voter) public voters; 
    // Tableau des propositions
    Proposal[] public proposals; 
    // Statut actuel du workflow
    WorkflowStatus public workflowStatus; 
    // Identifiant de la proposition gagnante
    uint public winningProposalId; 

    // Événements pour suivre les actions importantes
    event VoterRegistered(address voterAddress); // Émis lorsqu'un votant est enregistré
    event ProposalRegistered(uint proposalId);   // Émis lorsqu'une proposition est enregistrée
    event Voted(address voter, uint proposalId); // Émis lorsqu'un votant vote pour une proposition
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus); // Émis lors du changement de statut du workflow

    /**
     * @dev Constructeur qui initialise le propriétaire du contrat et le statut du workflow.
     * @param initialOwner Adresse du propriétaire initial du contrat.
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    /**
     * @dev Enregistre un votant.
     * @param _voterAddress L'adresse du votant à enregistrer.
     * @notice Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function registerVoter(address _voterAddress) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Voters can only be registered during the registering voters phase.");
        require(!voters[_voterAddress].isRegistered, "Voter is already registered.");

        // Enregistre le votant
        voters[_voterAddress].isRegistered = true;

        emit VoterRegistered(_voterAddress);
    }

    /**
     * @dev Démarre la phase d'enregistrement des propositions.
     * @notice Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function startProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Proposals registration can only be started after registering voters.");

        // Change le statut du workflow
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * @dev Termine la phase d'enregistrement des propositions.
     * @notice Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function endProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration phase must be started.");

        // Change le statut du workflow
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * @dev Enregistre une proposition.
     * @param _description La description de la proposition.
     * @notice Seuls les votants enregistrés peuvent enregistrer des propositions.
     */
    function registerProposal(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals can only be registered during the proposals registration phase.");
        require(voters[msg.sender].isRegistered, "Only registered voters can register proposals.");

        // Ajoute une nouvelle proposition dans le tableau des propositions
        proposals.push(Proposal(_description, 0));

        emit ProposalRegistered(proposals.length - 1);
    }

    /**
     * @dev Démarre la session de vote.
     * @notice Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function startVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Voting session can only be started after proposals registration.");

        // Change le statut du workflow
        workflowStatus = WorkflowStatus.VotingSessionStarted;

        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * @dev Termine la session de vote.
     * @notice Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session must be started.");

        // Change le statut du workflow
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * @dev Effectue un vote pour une proposition donnée.
     * @param _proposalId L'identifiant de la proposition.
     * @notice Seuls les votants enregistrés peuvent voter.
     */
    function vote(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Votes can only be cast during the voting session.");
        require(voters[msg.sender].isRegistered, "Only registered voters can vote.");
        require(!voters[msg.sender].hasVoted, "Voter has already voted.");
        require(_proposalId < proposals.length, "Invalid proposal.");

        // Enregistre le vote
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        // Augmente le nombre de votes pour la proposition
        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Décompte les votes et détermine la proposition gagnante.
     * @notice Seul le propriétaire du contrat peut appeler cette fonction.
     */
    function tallyVotes() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Votes can only be tallied after the voting session.");

        // Change le statut du workflow
        workflowStatus = WorkflowStatus.VotesTallied;

        uint winningVoteCount = 0;

        // Boucle pour trouver la proposition gagnante
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;
            }
        }

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    /**
     * @dev Retourne l'identifiant de la proposition gagnante.
     * @return L'identifiant de la proposition gagnante.
     */
    function getWinner() public view returns (uint) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Votes must be tallied before getting the winner.");
        return winningProposalId;
    }
}
