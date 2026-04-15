from datasets import load_dataset

# Load the entire dataset
dataset = load_dataset("ai-hyz/MemoryAgentBench")

# Access a specific split, e.g., 'Accurate_Retrieval'
accurate_retrieval_split = dataset["Accurate_Retrieval"]
print(f"Number of examples in Accurate_Retrieval split: {len(accurate_retrieval_split)}")
print(f"First example from Accurate_Retrieval split: {accurate_retrieval_split[0]}")

# Access another split, e.g., 'Test_Time_Learning'
test_time_learning_split = dataset["Test_Time_Learning"]
print(f"Number of examples in Test_Time_Learning split: {len(test_time_learning_split)}")
print(f"First example from Test_Time_Learning split: {test_time_learning_split[0]}")
