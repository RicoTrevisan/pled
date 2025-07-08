# Bubble.io Plugin CLI Tool - Implementation Plan

## Overview
Build an Elixir CLI tool that converts between Bubble.io plugin format (cryptic IDs) and human-readable format using display names from params.json files.

## Core Features to Implement

### 1. CLI Command Structure
- `pled compile` - Convert human-readable format to Bubble.io plugin format and upload
- `pled fetch` - Download plugin from Bubble.io and convert to human-readable format
- `pled convert` - Local conversion utilities (both directions)

### 2. Key Components

#### A. Plugin Structure Parser
- Parse `params.json` files to extract display names
- Handle different schemas (elements, element_actions, top-level actions)
- Map cryptic IDs (AAC-850m6) to display names (tiptap)

#### B. Directory Transformer
- Convert `elements/AAC-850m6/` → `elements/tiptap/`
- Convert `elements/AAC-850m6/element_actions/AAh-850pg/` → `elements/tiptap/actions/bold/`
- Handle nested structures and preserve file contents

#### C. Bubble.io API Client
- HTTP client for plugin upload/download (using existing Req dependency)
- Authentication handling
- Plugin packaging for upload

#### D. File System Operations
- Recursive directory traversal and transformation
- JSON parsing and manipulation
- File copying with structure preservation

### 3. Implementation Steps

1. **CLI Framework Setup**
   - Add CLI dependencies using `burrito`
   - Create command parsing and routing

2. **Core Data Structures**
   - Define structs for plugin components (Element, Action, etc.)
   - Create mapping functions between formats

3. **Conversion Engine**
   - Build bidirectional transformer
   - Handle edge cases and validation

4. **Bubble.io Integration**
   - Implement API client
   - Add upload/download functionality

5. **Testing & Documentation**
   - Unit tests for all transformations
   - Integration tests with sample data
   - Usage documentation

### 4. Technical Considerations

- **Error Handling**: Robust error handling for malformed plugins
- **Validation**: Ensure converted plugins maintain functionality
- **Configuration**: Support for API credentials and endpoints
- **Logging**: Detailed logging for debugging transformations

This plan leverages Elixir's strengths in pattern matching and data transformation while building a practical tool for Bubble.io plugin development.
