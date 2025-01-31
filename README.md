# MadridMetro
Database for the Madrid Metro Network ticket system.

I created this database while studying abroad in Madrid, Spain in April 2024. This database allows the user to register as a client, buy a personal Madrid Metro card, recharge it monthly, replace a card, and cancel a card.

If the cancelled card was prepard for the current month, the client must be able to replace the card number and keep the new card active. Otherwise, the card will not be active for the current month. 
The client can also buy a multi-entrance card. The first purchase must be at least €12 and to recharge this card, the minimum payment is €1.70. Each use for this card will deduct €1.70. 

The Madrid Metro has 3 types of clients, each with a different price: Abono Joven, Normal, and Senior. Abono Joven is for people under 26 years old or students, costing €20/month. Normal is for people over 26 and pricing is based on zones. Senior (over 65) costs €6.30/month. 

The zoning is divided up as follows:
![image](https://github.com/user-attachments/assets/58b7ac3c-7c58-4a21-b795-7befe8697cd7)

The pricing for the zones:
![image](https://github.com/user-attachments/assets/627f7de9-2154-4cd7-b9a8-637c1ae3e3d1)

There are also special discounts:
Big Family Normal: 20%
Big Family Special: 40%
Disability or seniors: 65%
