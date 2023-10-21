module defi::credit {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string;
    use sui::transfer;
    use std::vector;

    struct CreditRequest has key, store {
        id: UID,
        amount: u64,
        reason: string::String,
        loans: vector<Loan>
    }

    struct Loan has key, store {
        id: UID,
        balance: Balance<SUI>
    }

    public entry fun createCreditRequest(amount: u64, reason: string::String, ctx: &mut TxContext) {
        let application = CreditRequest {
            id: object::new(ctx),
            amount: amount,
            reason: reason,
            loans: vector::empty<Loan>()
        };

        transfer::public_transfer(application, tx_context::sender(ctx));
    }

    public entry fun addLoan(application: &mut CreditRequest, amount: Coin<SUI>, ctx: &mut TxContext) {
        let remain: u64 = getMissingFounds(application);

        assert!(remain < coin::value(&amount), 0);

        let loanBalance = coin::into_balance(amount);

        let loan = Loan {
            id: object::new(ctx),
            balance: loanBalance
        };

        vector::push_back(&mut application.loans, loan);
    }

    public entry fun executeCreditRequest(application: &mut CreditRequest, ctx: &mut TxContext) {
        assert!(getMissingFounds(application) != 0, 0);

        let CreditRequest {
            id: _id,
            amount: _amount,
            loans: loans,
            reason: _reason
        } = application;

        let app_length = vector::length(loans);
        let index: u64 = 0;
        let creditBalance: Balance<SUI> = balance::zero();

        while(index < app_length) {
            let loan = vector::borrow_mut(&mut application.loans, index);
            let loanBalance = balance::withdraw_all(&mut loan.balance);
            balance::join(&mut creditBalance, loanBalance);
        };

        transfer::public_transfer(coin::from_balance(creditBalance, ctx), tx_context::sender(ctx));
    }

    fun getMissingFounds(application: &CreditRequest): u64 {
        let collected: u64 = 0;
        let app_length = vector::length(&application.loans);
        let index: u64 = 0;

        while(index < app_length) {
            let loan = vector::borrow(&application.loans, index);
            collected = collected + balance::value(&loan.balance);
            index = index + 1;
        };

        let missingFounds = application.amount - collected;

        return missingFounds
    }
}
