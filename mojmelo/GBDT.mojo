from mojmelo.utils.BDecisionTree import BDecisionTree
from mojmelo.utils.Matrix import Matrix
from mojmelo.utils.utils import log_link, log_g, log_h, mse_link, mse_g, mse_h

struct GBDT():
	var criterion: String
	var loss_g: fn(Matrix, Matrix) raises -> Matrix
	var loss_h: fn(Matrix) raises -> Matrix
	var n_trees: Int
	var min_samples_split: Int
	var max_depth: Int
	var learning_rate: Float32
	var reg_lambda: Float32
	var gamma: Float32
	var trees: UnsafePointer[BDecisionTree]
	var score_start: Float32

	fn __init__(inout self,
		criterion: String = 'log',
		n_trees: Int = 10, min_samples_split: Int = 10, max_depth: Int = 3,
		learning_rate: Float32 = 0.1, reg_lambda: Float32 = 1.0, gamma: Float32 = 0.0
		):
		self.criterion = criterion.lower()
		if self.criterion == 'log':
			self.loss_g = log_g
			self.loss_h = log_h
		else:
			self.loss_g = mse_g
			self.loss_h = mse_h
		self.n_trees = n_trees
		self.min_samples_split = min_samples_split
		self.max_depth = max_depth
		self.learning_rate = learning_rate
		self.reg_lambda = reg_lambda
		self.gamma = gamma
		self.trees = UnsafePointer[BDecisionTree]()
		self.score_start = 0.0

	fn __del__(owned self):
		if self.trees:
			for i in range(self.n_trees):
				destroy_pointee(self.trees + i)
			self.trees.free()

	fn fit(inout self, X: Matrix, y: Matrix) raises:
		self.trees = UnsafePointer[BDecisionTree].alloc(self.n_trees)
		self.score_start = y.mean()
		var score = Matrix.full(X.height, 1, self.score_start)
		for i in range(self.n_trees):
			var tree = BDecisionTree(min_samples_split = self.min_samples_split, max_depth = self.max_depth, reg_lambda = self.reg_lambda, gamma = self.gamma)
			tree.fit(X, g = self.loss_g(y, score), h = self.loss_h(score))
			initialize_pointee_move(self.trees + i, tree)
			score += self.learning_rate * self.trees[i].predict(X)

	fn predict(self, X: Matrix) raises -> Matrix:
		var score = Matrix.full(X.height, 1, self.score_start)
		for i in range(self.n_trees):
			score += self.learning_rate * self.trees[i].predict(X)
		if self.criterion == 'mse':
			return mse_link(score)
		score = log_link(score)
		for i in range(score.size):
			score.data[i] = 1.0 if score.data[i] > 0.5 else 0.0
		return score^
