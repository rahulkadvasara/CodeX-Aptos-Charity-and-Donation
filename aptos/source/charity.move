module modules::charity {

    use std::signer;
    use std::string;
    use std::option;
    use std::vector;
    use std::address;
    use std::timestamp;

    // Struct to represent a charity
    struct CharitySystem has key {
        name: string::String,
        owner: address::Address,
        total_donations: u64,
        milestones: vector<Milestone>,
        spending_reports: vector<SpendingReport>, // Added for tracking expenditures
        is_verified: bool,
    }

    // Struct to represent a milestone for a charity
    struct Milestone has key {
        description: string::String,
        amount_needed: u64,
        amount_raised: u64,
        is_completed: bool,
    }

    // Struct to represent a donation
    struct Donation has key {
        donor: address::Address,
        amount: u64,
        charity_address: address::Address,
    }

    // Struct to represent a spending report
    struct SpendingReport has key {
        amount_spent: u64,
        description: string::String,
        timestamp: u64,
    }

    // Global storage for charities and donations
    struct CharityStorage has key {
        charities: vector<CharitySystem>,
        donations: vector<Donation>,
    }

    // Initialize the global storage
    public fun init(owner: &signer) {
        move_to(&signer::address_of(owner), CharityStorage {
            charities: vector::empty<CharitySystem>(),
            donations: vector::empty<Donation>(),
        });
    }

    // Register a new charity
    public fun register_charity(
        owner: &signer,
        name: string::String,
        milestones: vector<Milestone>
    ) {
        let address = signer::address_of(owner);
        let charity = CharitySystem {
            name,
            owner: address,
            total_donations: 0,
            milestones,
            spending_reports: vector::empty<SpendingReport>(), // Initialize empty reports
            is_verified: false, // Initially not verified
        };

        let storage = borrow_global_mut<CharityStorage>(signer::address_of(owner));
        vector::push_back(&mut storage.charities, charity);
    }

    // Verify a charity (only for admins)
    public fun verify_charity(admin: &signer, charity_address: address::Address) {
        let admin_address = signer::address_of(admin);
        let expected_admin_address: address::Address = admin_address; // Replace with actual deployer address
        assert!(admin_address == expected_admin_address, 1);

        let storage = borrow_global_mut<CharityStorage>(expected_admin_address);
        let charity_idx = find_charity(&storage.charities, charity_address);
        storage.charities[charity_idx].is_verified = true;
    }

    // Make a donation to a charity
    public fun donate_to_charity(
        donor: &signer,
        charity_address: address::Address,
        amount: u64
    ) {
        let donor_address = signer::address_of(donor);

        let storage = borrow_global_mut<CharityStorage>(donor_address);
        let charity_idx = find_charity(&storage.charities, charity_address);
        assert!(storage.charities[charity_idx].is_verified, 2); // Only verified charities can receive donations

        storage.charities[charity_idx].total_donations =storage.charities[charity_idx].total_donations + amount;

        // Record the donation
        let donation = Donation {
            donor: donor_address,
            amount,
            charity_address,
        };
        vector::push_back(&mut storage.donations, donation);

        // Allocate funds to milestones
        allocate_to_milestones(&mut storage.charities[charity_idx], amount);
    }

    // Log a spending report by the charity
    public fun log_spending_report(
        charity_owner: &signer,
        charity_address: address::Address,
        amount_spent: u64,
        description: string::String
    ) {
        let owner_address = signer::address_of(charity_owner);

        let storage = borrow_global_mut<CharityStorage>(owner_address);
        let charity_idx = find_charity(&storage.charities, charity_address);

        // Ensure only the charity owner can log spending reports
        assert!(storage.charities[charity_idx].owner == owner_address, 4);

        let report = SpendingReport {
            amount_spent,
            description,
            timestamp: timestamp::now_microseconds(),
        };
        
        vector::push_back(&mut storage.charities[charity_idx].spending_reports, report);
    }

    // Allocate funds to the charity's milestones
    public fun allocate_to_milestones(charity: &mut CharitySystem, amount: u64) acquire Milestone{

        let remaining_amount = amount ;

        for milestone in charity.milestones.iter_mut() {
            if !milestone.is_completed && remaining_amount > 0 {
                let needed = milestone.amount_needed - milestone.amount_raised;
                let allocation = if remaining_amount > needed {
                    needed
                } else {
                    remaining_amount
                };

                milestone.amount_raised += allocation;
                remaining_amount -= allocation;

                if milestone.amount_raised >= milestone.amount_needed {
                    milestone.is_completed = true;
                }
            }
        }
    }

    // Find a charity by its address
    fun find_charity(charities: &vector<CharitySystem>, charity_address: address::Address): u64 {
        let mut i = 0;
        let length = vector::length(charities);
        while i < length {
            if vector::borrow(charities, i).owner == charity_address {
                return i;
            }
            i = i + 1;
        }
        abort(3); // Charity not found
    }

    // View a charity's details
    public fun view_charity(charity_address: address::Address): option::Option<CharitySystem> {
        let storage = borrow_global<CharityStorage>(charity_address);
        let charity_idx = find_charity(&storage.charities, charity_address);
        option::some(vector::borrow(&storage.charities, charity_idx))
    }

    // View all donations for a charity
    public fun view_donations(charity_address: address::Address): vector<Donation> {
        let storage = borrow_global<CharityStorage>(charity_address);
        vector::filter(
            &storage.donations,
            fun (donation: &Donation): bool { donation.charity_address == charity_address }
        )
    }

    // View spending reports for a charity
    public fun view_spending_reports(charity_address: address::Address): vector<SpendingReport> {
        let storage = borrow_global<CharityStorage>(charity_address);
        let charity_idx = find_charity(&storage.charities, charity_address);
        storage.charities[charity_idx].spending_reports
    }
}