// <copyright file="ReadState.cs" company="WebDriver Committers">
// Licensed to the Software Freedom Conservancy (SFC) under one
// or more contributor license agreements. See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership. The SFC licenses this file
// to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// </copyright>

using System.Collections.Generic;

namespace OpenQA.Selenium.Safari.Internal
{
    /// <summary>
    /// Represents the state of a connection.
    /// </summary>
    internal class ReadState
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="ReadState"/> class.
        /// </summary>
        public ReadState()
        {
            this.Data = new List<byte>();
        }

        /// <summary>
        /// Gets the data of the current state.
        /// </summary>
        public List<byte> Data { get; private set; }

        /// <summary>
        /// Gets or sets the frame type of the current state.
        /// </summary>
        public FrameType? FrameType { get; set; }

        /// <summary>
        /// Clears the current state.
        /// </summary>
        public void Clear()
        {
            this.Data.Clear();
            this.FrameType = null;
        }
    }
}
