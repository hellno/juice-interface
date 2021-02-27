// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./libraries/Budget.sol";
import "./interfaces/IBudgetStore.sol";

import "./abstract/Store.sol";

/** 
  @notice An immutable contract to manage Budget states.
*/
contract BudgetStore is Store, IBudgetStore {
    using SafeMath for uint256;
    using Budget for Budget.Data;

    // --- private properties --- //

    // The official record of all Budgets ever created.
    mapping(uint256 => Budget.Data) private budgets;

    // --- public properties --- //

    /// @notice A big number to base ticket issuance off of.
    uint256 public constant BUDGET_BASE_WEIGHT = 1E10;

    /// @notice The latest Budget ID for each project address.
    mapping(address => uint256) public override latestBudgetId;

    /// @notice The number of yay and nay votes cast for each configuration of each Budget ID.
    mapping(uint256 => mapping(uint256 => mapping(bool => uint256)))
        public
        override votes;

    /// @notice The number of votes cast by each address for each configuration of each Budget ID.
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public
        override votesByAddress;

    /// @notice The total number of Budgets created, which is used for issuing Budget IDs.
    /// @dev Budgets have IDs > 0.
    uint256 public override budgetCount = 0;

    // --- external views --- //

    /**
        @notice Get the Budget with the given ID.
        @param _budgetId The ID of the Budget to get.
        @return _budget The Budget.
    */
    function getBudget(uint256 _budgetId)
        external
        view
        override
        returns (Budget.Data memory)
    {
        return budgets[_budgetId];
    }

    /**
        @notice The Budget that's next up for a project and not currently accepting payments.
        @param _project The project of the Budget being looked for.
        @return _budget The Budget.
    */
    function getQueuedBudget(address _project)
        external
        view
        override
        returns (Budget.Data memory)
    {
        Budget.Data memory _sBudget = _standbyBudget(_project);
        Budget.Data memory _aBudget = _activeBudget(_project);
        // If there are both active and standby budgets, the standby budget must be queued.
        if (_sBudget.id > 0 && _aBudget.id > 0) return _sBudget;
        require(_aBudget.id > 0, "BudgetStore::getQueuedBudget: NOT_FOUND");
        return _aBudget._nextUp();
    }

    /**
        @notice The Budget that would be currently accepting sustainments for the provided project.
        @param _project The project of the Budget being looked for.
        @return budget The Budget.
    */
    function getCurrentBudget(address _project)
        external
        view
        override
        returns (Budget.Data memory budget)
    {
        require(
            latestBudgetId[_project] > 0,
            "BudgetStore::getCurrentBudget: NOT_FOUND"
        );
        budget = _activeBudget(_project);
        if (budget.id > 0) return budget;
        budget = _standbyBudget(_project);
        if (budget.id > 0) return budget;
        budget = budgets[latestBudgetId[_project]];
        return budget._nextUp();
    }

    /**
        @notice The Budget that was created most recently for the specified project.
        @dev Should not throw.
        @param _project The project of the Budget being looked for.
        @return _budget The Budget.
    */
    function getLatestBudget(address _project)
        external
        view
        override
        returns (Budget.Data memory)
    {
        return budgets[latestBudgetId[_project]];
    }

    /**
        @notice The amount left to be withdrawn by the Budget's project.
        @param _budgetId The ID of the Budget to get the available sustainment from.
        @param _withhold The percent of the total to withhold from the total.
        @return amount The amount.
    */
    function getTappableAmount(uint256 _budgetId, uint256 _withhold)
        external
        view
        override
        returns (uint256)
    {
        require(
            _budgetId > 0 && _budgetId <= budgetCount,
            "BudgetStore::getTappableAmount:: NOT_FOUND"
        );
        return budgets[_budgetId]._tappableAmount(_withhold);
    }

    // --- external transactions --- //

    constructor() public {}

    /**
        @notice Configures the sustainability target and duration of the sender's current Budget if it hasn't yet received sustainments, or
        sets the properties of the Budget that will take effect once the current one expires.
        @dev The msg.sender is the project of the budget.
        @param _target The cashflow target to set.
        @param _duration The duration to set, measured in seconds.
        @param _want The token that this budget wants.
        @param _name The name of the budget.
        @param _link A link to information about the Budget.
        @param _discountRate A number from 95-100 indicating how valuable a contribution to the current Budget is 
        compared to the project's previous Budget.
        If it's 100, each Budget will have equal weight.
        If it's 95, each Money pool will be 95% as valuable as the previous Money pool's weight.
        @param _p The percentage of this Budget's overflow to reserve for the project.
        @param _b The amount of this Budget's overflow to give to a beneficiary address. 
        This can be another contract, or an end user address.
        An example would be a contract that reserves for Gitcoin grant matching.
        @param _bAddress The address of the beneficiary contract that can mint the reserved beneficiary percentage.
        @return _budgetId The ID of the Budget that was successfully configured.
    */
    function configure(
        uint256 _target,
        uint256 _duration,
        IERC20 _want,
        string calldata _name,
        string calldata _link,
        uint256 _discountRate,
        uint256 _p,
        uint256 _b,
        address _bAddress
    ) external override returns (uint256) {
        require(_target > 0, "Juicer::configureBudget: BAD_TARGET");
        // The `discountRate` token must be between 95 and 100.
        require(
            _discountRate >= 95 && _discountRate <= 100,
            "Juicer::configureBudget: BAD_BIAS"
        );
        // If the beneficiary reserve percentage is greater than 0, an address must be provided.
        require(
            _b == 0 || _bAddress != address(0),
            "Juicer::configureBudget: BAD_ADDRESS"
        );

        // The reserved project ticket percentage must be less than or equal to 100.
        require(_p <= 100, "Juicer::configureBudget: BAD_RESERVE_PERCENTAGES");

        // Return's the project's editable budget. Creates one if one doesn't already exists.
        Budget.Data storage _budget = _ensureStandbyBudget(msg.sender);

        // Set the properties of the budget.
        _budget.link = _link;
        _budget.name = _name;
        _budget.target = _target;
        _budget.duration = _duration;
        _budget.want = _want;
        _budget.discountRate = _discountRate;
        _budget.p = _p;
        _budget.b = _b;
        _budget.bAddress = _bAddress;
        _budget.configured = block.timestamp;

        emit Configure(
            _budget.id,
            _budget.project,
            _budget.target,
            _budget.duration,
            _budget.want,
            _budget.name,
            _budget.link,
            _budget.discountRate,
            _p,
            _b,
            _bAddress
        );

        return _budget.id;
    }

    /** 
      @notice Tracks a payments to the appropriate budget for the project.
      @param _project The project being paid.
      @param _payer The address that is paying.
      @param _amount The amount being paid.
      @param _votingPeriod The amount of time to allow for voting to complete before a reconfigured budget is eligible to receive payments.
      @param _withhold The percentage of a budgets target that should be withheld from the tappable target.
      @return budget The budget that is being paid.
      @return transferAmount The amount that should be transfered from the payer.
    */
    function payProject(
        address _project,
        address _payer,
        uint256 _amount,
        uint256 _votingPeriod,
        uint256 _withhold
    )
        external
        override
        onlyAdmin
        returns (Budget.Data memory budget, uint256 transferAmount)
    {
        // Find the Budget that this contribution should go towards.
        // Creates a new budget based on the project's most recent one if there isn't currently a Budget accepting contributions.
        Budget.Data storage _budget =
            _ensureActiveBudget(_project, _votingPeriod);

        // Add the amount to the Budget.
        _budget.total = _budget.total.add(_amount);

        // Get the amount of overflow funds that have been contributed to the Budget after this contribution is made.
        uint256 _overflow =
            _budget.total > _budget.target
                ? _budget.total.sub(_budget.target)
                : 0;

        if (_budget.project == _payer && _amount > _overflow) {
            // Mark the amount of the contribution that didn't go towards overflow as tapped.
            _budget.tapped = _budget.tapped.add(
                _amount.sub(_overflow).mul(uint256(100).sub(_withhold)).div(100)
            );
            // Transfer the overflow only, since the rest has been marked as tapped.
            if (_overflow > 0) transferAmount = _overflow;
        } else {
            transferAmount = _amount;
        }

        budget = _budget;
    }

    function tap(
        uint256 _budgetId,
        address _tapper,
        uint256 _amount,
        uint256 _fee
    ) external override onlyAdmin returns (Budget.Data memory) {
        // Get a reference to the Budget being tapped.
        Budget.Data storage _budget = budgets[_budgetId];

        require(_budget.id > 0, "BudgetStore::tap: NOT_FOUND");

        // Only a Budget project can tap its funds.
        require(_budget.project == _tapper, "BudgetStore::tap: UNAUTHORIZED");

        // The amount being tapped must be less than the tappable amount.
        require(
            _amount <= _budget._tappableAmount(_fee),
            "BudgetStore::tap: INSUFFICIENT_FUNDS"
        );

        // Add the amount to the Budget's tapped amount.
        _budget.tapped = _budget.tapped.add(_amount);

        return _budget;
    }

    // --- public transactions --- //

    /**
      @notice Add votes to the a particular reconfiguration proposal.
      @param _budgetId The ID of the budget whos reconfiguration is being voted on.
      @param _configured The time when the reconfiguration was proposed.
      @param _yay True if the vote is is support, false if not.
      @param _voter The address voting.
      @param _amount The amount of votes being cast.
     */
    function addVotes(
        uint256 _budgetId,
        uint256 _configured,
        bool _yay,
        address _voter,
        uint256 _amount
    ) external override onlyAdmin {
        votes[_budgetId][_configured][_yay] = votes[_budgetId][_configured][
            _yay
        ]
            .add(_amount);
        votesByAddress[_budgetId][_configured][_voter] = votesByAddress[
            _budgetId
        ][_configured][_voter]
            .add(_amount);
    }

    // --- private transactions --- //

    /**
        @notice Returns the standby Budget for this project if it exists, otherwise putting one in standby appropriately.
        @param _project The address who owns the Budget to look for.
        @return budget The resulting Budget.
    */
    function _ensureStandbyBudget(address _project)
        private
        returns (Budget.Data storage budget)
    {
        // Cannot update active budget, check if there is a standby budget
        budget = _standbyBudget(_project);
        if (budget.id > 0) return budget;
        budget = budgets[latestBudgetId[_project]];
        // If there's an active Budget, its end time should correspond to the start time of the new Budget.
        Budget.Data memory _aBudget = _activeBudget(_project);
        //Base a new budget on the latest budget if one exists.
        Budget.Data storage _newBudget =
            _aBudget.id > 0
                ? _initBudget(
                    _project,
                    _aBudget.start.add(_aBudget.duration),
                    budget
                )
                : _initBudget(_project, block.timestamp, budget);
        return _newBudget;
    }

    /**
        @notice Returns the active Budget for this project if it exists, otherwise activating one appropriately.
        @param _project The address who owns the Budget to look for.
        @param _votingPeriod The time between a Budget being configured and when it can become active.
        @return budget The resulting Budget.
    */
    function _ensureActiveBudget(address _project, uint256 _votingPeriod)
        private
        returns (Budget.Data storage budget)
    {
        // Check if there is an active Budget
        budget = _activeBudget(_project);
        if (budget.id > 0) return budget;
        // No active Budget found, check if there is a standby Budget
        budget = _standbyBudget(_project);
        // Budget if exists, has been in standby for enough time, and has more yay votes than nay, return it.
        if (
            budget.id > 0 &&
            ((budget.configured.add(_votingPeriod) < block.timestamp &&
                votes[budget.id][budget.configured][true] >
                votes[budget.id][budget.configured][false]) ||
                // allow if this is the first budget and it hasn't received payments.
                (budget.number == 1 && budget.total == 0))
        ) return budget;
        // No upcoming Budget found with a successful vote, clone the latest active Budget.
        // Use the standby Budget's previous budget if it exists but doesn't meet activation criteria.
        budget = budgets[
            budget.id > 0 ? budget.previous : latestBudgetId[_project]
        ];
        require(budget.id > 0, "BudgetStore::ensureActiveBudget: NOT_FOUND");
        // Use a start date that's a multiple of the duration.
        // This creates the effect that there have been scheduled Budgets ever since the `latest`, even if `latest` is a long time in the past.
        Budget.Data storage _newBudget =
            _initBudget(budget.project, budget._determineNextStart(), budget);
        return _newBudget;
    }

    /**
        @notice Initializes a Budget to be sustained for the sending address.
        @param _project The project of the Budget being initialized.
        @param _start The start time for the new Budget.
        @param _latestBudget The latest budget for the project.
        @return newBudget The initialized Budget.
    */
    function _initBudget(
        address _project,
        uint256 _start,
        Budget.Data memory _latestBudget
    ) private returns (Budget.Data storage newBudget) {
        budgetCount++;
        newBudget = budgets[budgetCount];
        newBudget.id = budgetCount;
        newBudget.start = _start;
        newBudget.total = 0;
        newBudget.tapped = 0;
        latestBudgetId[_project] = budgetCount;

        if (_latestBudget.id > 0) {
            newBudget._basedOn(_latestBudget);
        } else {
            newBudget.project = _project;
            newBudget.weight = BUDGET_BASE_WEIGHT;
            newBudget.number = 1;
            newBudget.previous = 0;
        }
    }

    /**
        @notice An project's edittable Budget.
        @param _project The project of the Budget being looked for.
        @return budget The standby Budget.
    */
    function _standbyBudget(address _project)
        private
        view
        returns (Budget.Data storage budget)
    {
        budget = budgets[latestBudgetId[_project]];
        if (budget.id == 0) return budgets[0];
        // There is no upcoming Budget if the latest Budget is not upcoming
        if (budget._state() != Budget.State.Standby) return budgets[0];
    }

    /**
        @notice The currently active Budget for a project.
        @param _project The project of the Budget being looked for.
        @return budget The active Budget.
    */
    function _activeBudget(address _project)
        private
        view
        returns (Budget.Data storage budget)
    {
        budget = budgets[latestBudgetId[_project]];
        if (budget.id == 0) return budgets[0];
        // An Active Budget must be either the latest Budget or the
        // one immediately before it.
        if (budget._state() == Budget.State.Active) return budget;
        budget = budgets[budget.previous];
        if (budget.id == 0 || budget._state() != Budget.State.Active)
            return budgets[0];
    }
}
