# Vim autocompletion

Current implementation properly builds a request.
Which may or may not be sent to openai.
The issue is that what is returned from Python to Vim is always an empty completion.

# TODO Investigate

Add logging to the 
fetch_completion_text
function
and ensure it is properly formed
and that the completion is properly returned

## Nit picks
- The initial prompt seems to be forcefully injected; it would be nice to remove it.
- The current triggers for autocompletion are too frequent and laggy and toggle insert mode once the request is over.
