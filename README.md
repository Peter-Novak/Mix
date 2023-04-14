# Intra

Parameters:
* ``iterationNumber``: arbitrary number, used to identify positions belonging to Intra
* ``positionSizeInLots``: positions size in lots. Recommended: for each 600 EUR take 0.5 lots. This should yield 10% monthly profit if used in combination with other recommended parameters.
* ``profitGoalInPoints``: goal expressed in points. Recommended: 0.01000
* ``gapBetweenPositions``: number of points between two positions. Recommended: 0.00100
* ``maxLossInPoints``: when this cumulative loss is reached, algoritm restarts. This is the same as saying... well shit, let's take this loss and start all over. It should take you between 10 - 20 days of trading to come back, if this happens. Recommended: 0.07000 
