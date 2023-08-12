The project is inspired from CacheGold's workflow 
which is explained in Chianlink's Tech-Talk # 15 
between Max Melcher and Dias Lonappan (CTO CacheGold)

Weblink: https://www.youtube.com/watch?v=tPURU6Sq2yo

I took inspiration from this talk to implement Gold-tokenization the CacheGold's way
in an MVP manner and learn everything along the way like-
-- how to use Chainlink Proof of Reserve feeds and Price feeds
-- forking mainnet, 
-- using Git on Remix, 
-- some gas optimizations like adding custom errors
-- clean code practices like NatSpec,
-- using complex data structures like nested mappings and structs

Execution:
It's pretty simple and fast to spin up and run on RemixIDE.

1. Open https://remix.ethereum.org/
2. Activate DGIT extension
3. Clone this public repo: https://github.com/ManuWeb3/GoldTokenization.git
4. Switch the environment to "Remix VM - Mainnet Fork"
5. Compile and Deploy the contract with at least 10 Ether to fund it.

4 Major functions the contract performs:
(I) Input new user's data that brought Gold to store in the vault and get it tokenized
Everytime a returning user gets back, a new "turn" is assigned with the latest data
(II) Run Purity and Weight test on the Gold bar
(III) If test passed, run mint() to mint the ERC-20 TGOLD tokens to the user's wallet
(IV) Whenever user wants, it to redeem the token into Ether/Wei back to its wallet.

Couple of helper functions available.