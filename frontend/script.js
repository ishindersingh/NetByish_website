// Update your script.js with this code
let conversationHistory = [];

// Image upload handler
document.getElementById('image-upload').addEventListener('change', function(e) {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function(e) {
            const chatBox = document.getElementById('chat-box');
            
            // Create image message
            const imgContainer = document.createElement('div');
            imgContainer.className = 'message user-message';
            
            const img = document.createElement('img');
            img.className = 'uploaded-image';
            img.src = e.target.result;
            
            // Add image to chat
            imgContainer.appendChild(img);
            chatBox.appendChild(imgContainer);
            
            // Add to conversation history
            conversationHistory.push({
                role: 'user',
                content: [
                    { type: 'text', text: 'User uploaded an image' },
                    { type: 'image_url', image_url: { url: e.target.result } }
                ]
            });

            chatBox.scrollTop = chatBox.scrollHeight;
        };
        reader.readAsDataURL(file);
    }
});

async function sendMessage() {
    const input = document.getElementById('user-input');
    const message = input.value.trim();
    if (!message) return;

    input.value = '';
    const chatBox = document.getElementById('chat-box');

    // Add user message
    addMessage('user', message);

    try {
        // Add typing indicator
        const typingIndicator = addTypingIndicator();

        // API call
        const response = await fetch('https://ishinderss-ai.onrender.com', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ messages: conversationHistory })
        });

        const data = await response.json();
        const reply = data.choices[0].message.content;
        
        // Remove typing indicator
        chatBox.removeChild(typingIndicator);

        // Add AI message
        addMessage('assistant', reply);

    } catch (error) {
        console.error('Error:', error);
        addMessage('error', 'An error occurred. Please try again.');
    }
}

function addMessage(role, content) {
    const chatBox = document.getElementById('chat-box');
    
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role === 'user' ? 'user-message' : 'ai-message'}`;
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.innerHTML = marked.parse(content, {
        highlight: (code, lang) => {
            const language = Prism.languages[lang] ? lang : 'plaintext';
            return Prism.highlight(code, Prism.languages[language], language);
        }
    });
    
    messageDiv.appendChild(contentDiv);
    chatBox.appendChild(messageDiv);
    Prism.highlightAllUnder(contentDiv);
    
    // Update conversation history
    if (role !== 'error') {
        conversationHistory.push({
            role: role === 'user' ? 'user' : 'assistant',
            content: content
        });
    }

    chatBox.scrollTop = chatBox.scrollHeight;
}

function addTypingIndicator() {
    const chatBox = document.getElementById('chat-box');
    
    const typingDiv = document.createElement('div');
    typingDiv.className = 'message ai-message typing-indicator';
    
    const dots = document.createElement('div');
    dots.className = 'typing-dots';
    for (let i = 0; i < 3; i++) {
        dots.appendChild(document.createElement('div'));
    }
    
    typingDiv.appendChild(dots);
    chatBox.appendChild(typingDiv);
    
    chatBox.scrollTop = chatBox.scrollHeight;
    return typingDiv;
}

// Handle Enter key
document.getElementById('user-input').addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
    }
});

// Initialize Marked.js
marked.setOptions({
    breaks: true,
    gfm: true,
    headerIds: false,
    mangle: false
});

// Initialize Prism
Prism.manual = true;
